import AVFoundation

/// Shared audio-session handoff between the mic (`SpeechManager`) and Kit's voice
/// (`KittVoice`). Releasing the session posts an interruption notification; both
/// components ignore those self-triggered events so we don't recurse into a crash.
enum KitAudioSession {
    private(set) static var isReleasing = false

    static func configureForMic() throws {
        release()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .duckOthers, .allowBluetoothHFP]
        )
        try session.setActive(true)
    }

    /// TTS after the mic — playback only, so the recorder graph is fully torn down first.
    static func configureForPlayback() throws {
        release()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playback,
            mode: .spokenAudio,
            options: [.duckOthers]
        )
        try session.setActive(true)
    }

    static func release() {
        guard !isReleasing else { return }
        isReleasing = true
        defer { isReleasing = false }
        // Skip notifyOthersOnDeactivation — it was triggering extra interruption
        // loops between the mic and TTS observers.
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
