//
//  AudioSessionManager.swift
//  Ears
//
//  Manages AVAudioSession for background playback and interruption handling
//

import AVFoundation
import UIKit

/// Manages the AVAudioSession for proper background playback and interruption handling.
///
/// Key responsibilities:
/// - Configure audio session category for background playback
/// - Handle interruptions (phone calls, Siri, other apps)
/// - Handle route changes (headphones plugged/unplugged)
/// - Manage audio ducking when needed
final class AudioSessionManager {
    // MARK: - Properties

    private let session = AVAudioSession.sharedInstance()

    /// Callback when audio is interrupted (e.g., phone call)
    var onInterruption: ((InterruptionType) -> Void)?

    /// Callback when audio route changes (e.g., headphones unplugged)
    var onRouteChange: ((RouteChangeReason) -> Void)?

    // MARK: - Types

    enum InterruptionType {
        case began
        case ended(shouldResume: Bool)
    }

    enum RouteChangeReason {
        case headphonesUnplugged
        case headphonesPluggedIn
        case other
    }

    // MARK: - Initialization

    init() {
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Configuration

    /// Configure the audio session for audiobook playback.
    /// Should be called once at app startup.
    func configure() {
        do {
            // Use playback category for audio-only content
            // Spoken word mode optimization for audiobooks
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]
            )

            // Allow background playback
            try session.setActive(false)

        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    /// Activate the audio session before playback.
    func activate() throws {
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// Deactivate the audio session when stopping playback.
    func deactivate() {
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Deactivation can fail if another app is using audio, which is fine
            print("Audio session deactivation note: \(error)")
        }
    }

    // MARK: - Notifications

    private func setupNotifications() {
        // Interruption notifications (phone calls, Siri, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: session
        )

        // Route change notifications (headphones plugged/unplugged)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: session
        )

        // App lifecycle for audio session management
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // Audio interrupted - another app took over
            onInterruption?(.began)

        case .ended:
            // Interruption ended
            var shouldResume = false

            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                shouldResume = options.contains(.shouldResume)
            }

            onInterruption?(.ended(shouldResume: shouldResume))

        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            // Headphones unplugged - pause playback (standard behavior)
            if let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                // Check if headphones were the old output
                let hadHeadphones = previousRoute.outputs.contains { output in
                    [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains(output.portType)
                }
                if hadHeadphones {
                    onRouteChange?(.headphonesUnplugged)
                }
            }

        case .newDeviceAvailable:
            // New device connected (headphones plugged in)
            let currentOutputs = session.currentRoute.outputs
            let hasHeadphones = currentOutputs.contains { output in
                [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains(output.portType)
            }
            if hasHeadphones {
                onRouteChange?(.headphonesPluggedIn)
            }

        default:
            onRouteChange?(.other)
        }
    }

    @objc private func handleAppWillResignActive() {
        // App is going to background - audio continues due to background mode
        // But we might want to do some cleanup or state saving here
    }

    // MARK: - Utility

    /// Check if headphones are currently connected
    var isHeadphonesConnected: Bool {
        let outputs = session.currentRoute.outputs
        return outputs.contains { output in
            [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains(output.portType)
        }
    }

    /// Current output device name
    var currentOutputDevice: String {
        session.currentRoute.outputs.first?.portName ?? "Speaker"
    }
}
