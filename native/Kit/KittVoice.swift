import AVFoundation

@MainActor
final class KittVoice: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    var onFinishSpeaking: (() -> Void)?

    private var interruptionObserver: NSObjectProtocol?
    private var utteranceGeneration = 0

    /// A warm English voice. Prefers a premium/enhanced en-GB voice if the user
    /// has downloaded one (Settings › Accessibility › Spoken Content › Voices),
    /// falls back to the stock voice otherwise.
    private static let warmVoice: AVSpeechSynthesisVoice? = {
        let enGB = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-GB" }
        return enGB.first { $0.quality == .premium }
            ?? enGB.first { $0.quality == .enhanced }
            ?? AVSpeechSynthesisVoice(language: "en-GB")
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }()

    override init() {
        super.init()
        synthesizer.delegate = self
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor [weak self] in
                self?.handleInterruption(note)
            }
        }
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    private func handleInterruption(_ note: Notification) {
        guard
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return }

        switch type {
        case .began:
            guard !KitAudioSession.isReleasing else { return }
            guard synthesizer.isSpeaking || synthesizer.isPaused else { return }
            utteranceGeneration += 1
            synthesizer.stopSpeaking(at: .immediate)
        case .ended:
            let options: AVAudioSession.InterruptionOptions = {
                guard let raw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt else { return [] }
                return AVAudioSession.InterruptionOptions(rawValue: raw)
            }()
            guard options.contains(.shouldResume) else { return }
            try? KitAudioSession.configureForPlayback()
        @unknown default:
            break
        }
    }

    func speak(_ text: String) {
        let clipped = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clipped.isEmpty else {
            finishSpeaking(generation: utteranceGeneration)
            return
        }

        utteranceGeneration += 1
        let generation = utteranceGeneration

        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }

        do {
            try KitAudioSession.configureForPlayback()
        } catch {
            finishSpeaking(generation: generation)
            return
        }

        let utterance = AVSpeechUtterance(string: clipped)
        utterance.voice = Self.warmVoice
        utterance.rate = 0.46
        utterance.pitchMultiplier = 0.96
        utterance.preUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }

    func stop() {
        guard synthesizer.isSpeaking || synthesizer.isPaused else { return }
        utteranceGeneration += 1
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func finishSpeaking(generation: Int) {
        guard generation == utteranceGeneration else { return }
        KitAudioSession.release()
        onFinishSpeaking?()
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.finishSpeaking(generation: self.utteranceGeneration)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, !self.synthesizer.isSpeaking else { return }
            self.finishSpeaking(generation: self.utteranceGeneration)
        }
    }
}
