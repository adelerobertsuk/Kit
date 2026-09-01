import AVFoundation
import Combine
import UIKit

/// Reads a tape out loud. Play is the text, not an audio file.
@MainActor
final class TapeVoice: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var playingID: UUID?

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle(entry: JournalEntry) {
        if playingID == entry.id {
            stop()
            return
        }
        speak(entry)
    }

    func speak(_ entry: JournalEntry) {
        stop()
        let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = 0.46
        playingID = entry.id
        synthesizer.speak(utterance)
        KitHaptics.soft()
    }

    func stop() {
        guard synthesizer.isSpeaking || playingID != nil else { return }
        synthesizer.stopSpeaking(at: .immediate)
        playingID = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            playingID = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            playingID = nil
        }
    }
}
