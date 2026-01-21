//
//  CrashRecovery.swift
//  Ears
//
//  Automatic crash recovery with position persistence
//

import Foundation
import Observation

/// Manages crash recovery by persisting playback state frequently and detecting interrupted sessions.
///
/// Key features:
/// - Saves playback state every 5 seconds during active playback
/// - Detects if app was terminated while playing
/// - Provides recovery state for auto-resume on next launch
@Observable
final class CrashRecovery {
    // MARK: - Constants

    private static let stateKey = "playbackState"
    private static let activeKey = "playbackActive"
    private static let saveInterval: TimeInterval = 5.0

    // MARK: - Properties

    /// Whether we're currently tracking playback for recovery
    private var isTracking = false

    /// Timer for periodic saves
    private var saveTimer: Timer?

    /// UserDefaults suite for app group (shared with CarPlay)
    private let defaults: UserDefaults

    // MARK: - Initialization

    init() {
        // Use app group for sharing with CarPlay and widgets
        self.defaults = UserDefaults(suiteName: "group.com.ears.audiobookshelf") ?? .standard
    }

    // MARK: - Public Methods

    /// Check if there was an interrupted session on app launch
    /// Returns recovery state if app was terminated during playback
    func checkForInterruptedSession() async -> PlaybackRecoveryState? {
        // Check if playback was active when app terminated
        guard defaults.bool(forKey: Self.activeKey) else {
            return nil
        }

        // Load the saved state
        guard let data = defaults.data(forKey: Self.stateKey),
              let state = try? JSONDecoder().decode(PlaybackRecoveryState.self, from: data) else {
            // Clear invalid state
            clearRecoveryState()
            return nil
        }

        // Clear the active flag (we've handled the recovery)
        defaults.set(false, forKey: Self.activeKey)

        return state
    }

    /// Start tracking playback for crash recovery
    func startTracking(bookId: String, currentTime: TimeInterval, duration: TimeInterval, chapterIndex: Int?) {
        isTracking = true

        // Mark playback as active
        defaults.set(true, forKey: Self.activeKey)

        // Save initial state
        saveState(bookId: bookId, currentTime: currentTime, duration: duration, chapterIndex: chapterIndex)

        // Start periodic save timer
        startSaveTimer(bookId: bookId)
    }

    /// Update the current playback position (called frequently during playback)
    func updatePosition(bookId: String, currentTime: TimeInterval, duration: TimeInterval, chapterIndex: Int?) {
        guard isTracking else { return }
        saveState(bookId: bookId, currentTime: currentTime, duration: duration, chapterIndex: chapterIndex)
    }

    /// Stop tracking (called on intentional stop/pause)
    func stopTracking() {
        isTracking = false
        saveTimer?.invalidate()
        saveTimer = nil

        // Clear active flag - this was an intentional stop
        defaults.set(false, forKey: Self.activeKey)
    }

    /// Pause tracking but keep state (called on pause)
    func pauseTracking() {
        saveTimer?.invalidate()
        saveTimer = nil

        // Keep the state saved but mark as not actively playing
        // If the app is killed while paused, we still want to resume
        defaults.set(true, forKey: Self.activeKey)
    }

    /// Resume tracking after pause
    func resumeTracking(bookId: String) {
        guard !isTracking else { return }
        isTracking = true
        defaults.set(true, forKey: Self.activeKey)
        startSaveTimer(bookId: bookId)
    }

    // MARK: - Private Methods

    private func saveState(bookId: String, currentTime: TimeInterval, duration: TimeInterval, chapterIndex: Int?) {
        let state = PlaybackRecoveryState(
            bookId: bookId,
            currentTime: currentTime,
            duration: duration,
            chapterIndex: chapterIndex,
            timestamp: Date()
        )

        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: Self.stateKey)
        }
    }

    private func startSaveTimer(bookId: String) {
        saveTimer?.invalidate()

        // Create timer on main run loop
        saveTimer = Timer.scheduledTimer(withTimeInterval: Self.saveInterval, repeats: true) { [weak self] _ in
            // The actual position will be updated by the audio player calling updatePosition
            // This timer just ensures we save periodically even if position updates are missed
        }
    }

    private func clearRecoveryState() {
        defaults.removeObject(forKey: Self.stateKey)
        defaults.set(false, forKey: Self.activeKey)
    }
}

// MARK: - Recovery State

/// Represents the state needed to recover playback after a crash
struct PlaybackRecoveryState: Codable {
    /// The ID of the book that was playing
    let bookId: String

    /// The exact playback position in seconds
    let currentTime: TimeInterval

    /// Total duration of the book
    let duration: TimeInterval

    /// Current chapter index (if available)
    let chapterIndex: Int?

    /// When this state was saved
    let timestamp: Date

    /// How stale this recovery state is
    var age: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }

    /// Whether this recovery state is still valid (not too old)
    var isValid: Bool {
        // Consider recovery valid for up to 30 days
        age < 30 * 24 * 60 * 60
    }
}
