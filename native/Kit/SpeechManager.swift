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
    /// Start of this listen burst. Nil when the mic is off. The console clock uses this, not the session age.
    @Published var listenStartedAt: Date?

    /// Delivers the finished turn: `text` is the tidied version written to the
    /// journal, `raw` is the verbatim transcript kept alongside it.
    var onFinalTranscript: ((_ text: String, _ raw: String) -> Void)?
    var onEmptyListen: (() -> Void)?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    /// The request the audio tap appends buffers to. Held apart from `recognitionRequest`
    /// only so the tap (audio thread) can reach it; it's swapped on the main actor when a
    /// long monologue outlives one recognition segment. `nonisolated(unsafe)` is sound:
    /// `SFSpeechAudioBufferRecognitionRequest.append` is documented safe from the audio
    /// callback, and the pointer only changes between segments.
    private nonisolated(unsafe) var liveRequest: SFSpeechAudioBufferRecognitionRequest?

    /// Text banked from earlier segments this burst — prepended to the live segment so a
    /// recycled recogniser never makes the transcript appear to shrink.
    private var committedSegments = ""
    private var recycleCount = 0
    private var lastRecycleAt: Date?

    private var lastLoudDate: Date?
    private var lastTranscriptChange: Date?
    private var hasHeardSpeech = false
    private var hasTap = false
    private var peakLevel: Float = 0

    private nonisolated(unsafe) var pendingLevel: Float = 0
    private nonisolated(unsafe) var levelTickScheduled = false

    private let silenceDuration: TimeInterval = 1.5

    private var interruptionObserver: NSObjectProtocol?

    init() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.handleInterruption(note) }
        }
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    /// A system alarm, timer, or incoming call takes the audio session out from under
    /// an active listen. The recognition task can't survive that, so on `.began` we
    /// commit whatever's been heard rather than lose it — same rule as everywhere else
    /// in Kit: captured speech is never dropped. Nothing to auto-resume on `.ended`;
    /// the next tap-to-talk reconfigures the session from scratch.
    private func handleInterruption(_ note: Notification) {
        guard
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return }

        switch type {
        case .began:
            guard !KitAudioSession.isReleasing else { return }
            if isListening { stopListening(playHaptic: false) }
        case .ended:
            break
        @unknown default:
            break
        }
    }

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
        guard !isListening else { return }
        liveTranscript = ""
        committedSegments = ""
        recycleCount = 0
        lastRecycleAt = nil
        hasHeardSpeech = false
        lastLoudDate = nil
        lastTranscriptChange = nil
        peakLevel = 0

        do {
            try KitAudioSession.configureForMic()
        } catch {
            return
        }

        let inputNode = audioEngine.inputNode
        if hasTap {
            inputNode.removeTap(onBus: 0)
            hasTap = false
        }

        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { return }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard buffer.frameLength > 0 else { return }
            self?.liveRequest?.append(buffer)
            let level = SpeechManager.rmsLevel(buffer: buffer)
            self?.enqueueLevel(level)
        }
        hasTap = true

        beginRecognitionSegment()

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            if hasTap {
                inputNode.removeTap(onBus: 0)
                hasTap = false
            }
            recognitionTask?.cancel()
            recognitionTask = nil
            recognitionRequest = nil
            liveRequest = nil
            return
        }

        listenStartedAt = Date()
        isListening = true
    }

    /// Spins up a fresh recognition request + task and points the audio tap at it.
    /// Runs once when a listen starts, then again whenever a segment ends early
    /// (the recogniser's own length cap, or a transient fault) while speech is still
    /// going — that recycling is what lets a long braindump run without the turn
    /// cutting itself off.
    private func beginRecognitionSegment() {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Let Apple's recogniser insert sentence breaks at the source; TranscriptCleaner
        // still handles fillers and stutter-repeats on the finished turn.
        if #available(iOS 16.0, *) { request.addsPunctuation = true }
        recognitionRequest = request
        liveRequest = request

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let live = self.combined(with: result.bestTranscription.formattedString)
                    if live != self.liveTranscript {
                        self.liveTranscript = live
                        self.lastTranscriptChange = Date()
                    }
                }
                if result?.isFinal == true {
                    self.stopListening(playHaptic: false)
                } else if error != nil {
                    if self.isListening && self.hasHeardSpeech {
                        self.recycleRecognitionSegment()
                    } else {
                        self.stopListening(playHaptic: false)
                    }
                }
            }
        }
    }

    /// Bank the text heard so far and hand off to a fresh segment without touching the
    /// mic — the tap keeps running, only the recogniser is swapped. Bounded: three
    /// failures inside a second means recognition is genuinely down, so commit and stop.
    private func recycleRecognitionSegment() {
        let now = Date()
        if let last = lastRecycleAt, now.timeIntervalSince(last) < 1.0 {
            recycleCount += 1
        } else {
            recycleCount = 1
        }
        lastRecycleAt = now
        guard recycleCount <= 3 else {
            stopListening(playHaptic: false)
            return
        }

        committedSegments = liveTranscript
        let retiring = recognitionRequest
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        beginRecognitionSegment()
        retiring?.endAudio()
    }

    /// Coalesce meter work to ~20 Hz — one dispatch per audio buffer was flooding the
    /// main actor and taking Kit down after a minute of back-and-forth.
    private nonisolated func enqueueLevel(_ level: Float) {
        pendingLevel = level
        guard !levelTickScheduled else { return }
        levelTickScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.levelTickScheduled = false
            guard self.isListening else { return }
            self.handleLevel(self.pendingLevel)
        }
    }

    private func combined(with segment: String) -> String {
        let seg = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        if committedSegments.isEmpty { return seg }
        if seg.isEmpty { return committedSegments }
        return committedSegments + " " + seg
    }

    private func handleLevel(_ rawLevel: Float) {
        audioLevel = min(1.0, (audioLevel * 0.55) + (rawLevel * 0.45))

        let now = Date()
        peakLevel = max(peakLevel * 0.97, rawLevel)
        let loudCutoff = max(0.035, peakLevel * 0.22)

        if rawLevel > loudCutoff {
            hasHeardSpeech = true
            lastLoudDate = now
        }

        guard hasHeardSpeech else { return }

        if let lastLoudDate, now.timeIntervalSince(lastLoudDate) >= silenceDuration {
            stopListening(playHaptic: true)
            return
        }

        if !liveTranscript.isEmpty,
           let lastTranscriptChange,
           now.timeIntervalSince(lastTranscriptChange) >= silenceDuration {
            stopListening(playHaptic: true)
        }
    }

    private func stopListening(playHaptic: Bool) {
        guard isListening else { return }
        teardownAudio()

        if playHaptic {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        // Tidy the mechanical debris of talking on the move (fillers, stutter-repeats,
        // missing capitals/stops) before the turn is committed. Local, deterministic,
        // no network — the live drawer above still shows the raw partials.
        let raw = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        liveTranscript = ""
        let text = TranscriptCleaner.clean(raw)
        if text.isEmpty {
            onEmptyListen?()
        } else {
            onFinalTranscript?(text, raw)
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
        levelTickScheduled = false
        liveRequest = nil

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        if hasTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        isListening = false
        listenStartedAt = nil
        audioLevel = 0

        KitAudioSession.release()
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
