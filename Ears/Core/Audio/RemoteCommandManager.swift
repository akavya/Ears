//
//  RemoteCommandManager.swift
//  Ears
//
//  Handles remote control commands from lock screen, Control Center, headphones, and CarPlay
//

import MediaPlayer

/// Manages remote control commands from:
/// - Lock screen controls
/// - Control Center
/// - Headphone buttons (single/double/triple tap)
/// - CarPlay
/// - Siri
final class RemoteCommandManager {
    // MARK: - Callbacks

    var onPlay: (() -> MPRemoteCommandHandlerStatus)?
    var onPause: (() -> MPRemoteCommandHandlerStatus)?
    var onTogglePlayPause: (() -> MPRemoteCommandHandlerStatus)?
    var onStop: (() -> MPRemoteCommandHandlerStatus)?
    var onSkipForward: ((TimeInterval) -> MPRemoteCommandHandlerStatus)?
    var onSkipBackward: ((TimeInterval) -> MPRemoteCommandHandlerStatus)?
    var onSeek: ((TimeInterval) -> MPRemoteCommandHandlerStatus)?
    var onNextTrack: (() -> MPRemoteCommandHandlerStatus)?
    var onPreviousTrack: (() -> MPRemoteCommandHandlerStatus)?
    var onChangePlaybackRate: ((Float) -> MPRemoteCommandHandlerStatus)?

    // MARK: - Properties

    private let commandCenter = MPRemoteCommandCenter.shared()

    /// Skip intervals (can be customized in settings)
    var skipForwardInterval: TimeInterval = 30
    var skipBackwardInterval: TimeInterval = 15

    // MARK: - Registration

    /// Register all remote command handlers
    func register() {
        // Play
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.onPlay?() ?? .commandFailed
        }

        // Pause
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.onPause?() ?? .commandFailed
        }

        // Toggle play/pause (single tap on AirPods)
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.onTogglePlayPause?() ?? .commandFailed
        }

        // Stop
        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget { [weak self] _ in
            self?.onStop?() ?? .commandFailed
        }

        // Skip forward (double tap forward on AirPods)
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: skipForwardInterval)]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let self = self,
                  let skipEvent = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }
            return self.onSkipForward?(skipEvent.interval) ?? .commandFailed
        }

        // Skip backward (double tap backward on AirPods)
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipBackwardInterval)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let self = self,
                  let skipEvent = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }
            return self.onSkipBackward?(skipEvent.interval) ?? .commandFailed
        }

        // Seek (scrubbing on lock screen)
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            return self.onSeek?(positionEvent.positionTime) ?? .commandFailed
        }

        // Next track (maps to next chapter)
        // Triple tap on AirPods or next button on CarPlay
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.onNextTrack?() ?? .commandFailed
        }

        // Previous track (maps to previous chapter)
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.onPreviousTrack?() ?? .commandFailed
        }

        // Playback rate
        commandCenter.changePlaybackRateCommand.isEnabled = true
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
        commandCenter.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let self = self,
                  let rateEvent = event as? MPChangePlaybackRateCommandEvent else {
                return .commandFailed
            }
            return self.onChangePlaybackRate?(rateEvent.playbackRate) ?? .commandFailed
        }

        // Disable commands we don't support
        commandCenter.seekForwardCommand.isEnabled = false
        commandCenter.seekBackwardCommand.isEnabled = false
        commandCenter.ratingCommand.isEnabled = false
        commandCenter.likeCommand.isEnabled = false
        commandCenter.dislikeCommand.isEnabled = false
        commandCenter.bookmarkCommand.isEnabled = false
    }

    /// Unregister all handlers
    func unregister() {
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.stopCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackRateCommand.removeTarget(nil)
    }

    /// Update skip intervals (from settings)
    func updateSkipIntervals(forward: TimeInterval, backward: TimeInterval) {
        skipForwardInterval = forward
        skipBackwardInterval = backward

        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: forward)]
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: backward)]
    }
}
