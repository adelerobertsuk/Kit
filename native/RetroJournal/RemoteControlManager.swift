import MediaPlayer

/// Lets an AirPods stem press (mapped to play/pause) trigger KITT hands-free,
/// matching the zero-gaze interaction goal. Relies on KITT holding "Now Playing"
/// status, which iOS grants after KITT's own TTS audio has played — so the very
/// first turn of a session still needs the on-screen button.
final class RemoteControlManager {
    private let commandCenter = MPRemoteCommandCenter.shared()

    func start(onTogglePressed: @escaping () -> Void) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "KITT",
            MPNowPlayingInfoPropertyPlaybackRate: 0.0
        ]

        let handler: (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus = { _ in
            onTogglePressed()
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget(handler: handler)
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget(handler: handler)
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget(handler: handler)
    }
}
