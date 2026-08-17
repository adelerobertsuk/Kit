import Foundation
import AVFoundation
import Speech
import Combine
import UIKit

@MainActor
final class SpeechManager: ObservableObject {
    @Published var isListening = false
    @Published var liveTranscript = ""
    @Published var audioLevel: Float = 0
    @Published var permissionDenied = false

    var onFinalTranscript: ((String) -> Void)?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var lastLoudDate: Date?
    private var hasHeardSpeech = false

    private let silenceThreshold: Float = 0.02
    private let silenceDuration: TimeInterval = 1.5

    func toggleTalk() {
        if isListening {
            stopListening(playHaptic: true)
        } else {
            requestPermissionsThenStart()
        }
    }

    private func requestPermissionsThenStart() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            AVAudioApplication.requestRecordPermission { granted in
                Task { @MainActor in
                    guard let self else { return }
                    if authStatus == .authorized && granted {
                        self.permissionDenied = false
                        self.startListening()
                    } else {
                        self.permissionDenied = true
                    }
                }
            }
        }
    }

    private func startListening() {
        guard !audioEngine.isRunning else { return }
        liveTranscript = ""
        hasHeardSpeech = false
        lastLoudDate = nil

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            let level = SpeechManager.rmsLevel(buffer: buffer)
            Task { @MainActor in
                self?.handleLevel(level)
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            return
        }

        isListening = true

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.liveTranscript = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.stopListening(playHaptic: false)
                }
            }
        }
    }

    private func handleLevel(_ rawLevel: Float) {
        audioLevel = min(1.0, (audioLevel * 0.6) + (rawLevel * 0.4))

        let now = Date()
        if rawLevel > silenceThreshold {
            hasHeardSpeech = true
            lastLoudDate = now
        }

        guard hasHeardSpeech, let lastLoudDate else { return }
        if now.timeIntervalSince(lastLoudDate) >= silenceDuration {
            stopListening(playHaptic: true)
        }
    }

    private func stopListening(playHaptic: Bool) {
        guard isListening else { return }
        teardownAudio()

        if playHaptic {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        let text = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        liveTranscript = ""
        if !text.isEmpty {
            onFinalTranscript?(text)
        }
    }

    /// MUTE: stops the current turn without submitting whatever's been heard so far.
    func cancelListening() {
        guard isListening else { return }
        teardownAudio()
        liveTranscript = ""
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    private func teardownAudio() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        isListening = false
        audioLevel = 0
    }

    private static func rmsLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }
        let samples = channelData[0]
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += samples[i] * samples[i]
        }
        let rms = sqrtf(sum / Float(frameLength))
        return min(1.0, rms * 8)
    }
}
