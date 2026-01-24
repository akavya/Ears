//
//  SleepTimer.swift
//  Ears
//
//  Sleep timer with fade-out and auto-restart functionality
//

import Foundation
import Observation

/// A sleep timer that pauses playback after a specified duration.
///
/// Features:
/// - Configurable duration (5 min to 2 hours, or end of chapter)
/// - Fade-out effect before pause
/// - Auto-restart when playback resumes (like BookPlayer)
/// - Shake to extend (adds 5 minutes)
@Observable
final class SleepTimer {
    // MARK: - State

    enum State: Equatable {
        case inactive
        case active(remaining: TimeInterval)
        case endOfChapter

        var isActive: Bool {
            switch self {
            case .inactive: return false
            case .active, .endOfChapter: return true
            }
        }
    }

    // MARK: - Properties

    /// Current timer state
    private(set) var state: State = .inactive

    /// Time remaining (for UI display)
    var remainingTime: TimeInterval {
        switch state {
        case .inactive:
            return 0
        case .active(let remaining):
            return remaining
        case .endOfChapter:
            return 0 // Shows "End of Chapter" instead
        }
    }

    /// Whether auto-restart is enabled
    var autoRestartEnabled: Bool = false

    /// Duration to use when auto-restarting
    var autoRestartDuration: TimeInterval = 900 // 15 minutes default

    /// Callback when timer fires
    var onTimerFired: (() -> Void)?

    // MARK: - Private Properties

    private var endTime: Date?
    private var endOfChapterTime: TimeInterval?
    private var wasActiveBeforePause = false
    private var previousDuration: TimeInterval = 0

    // MARK: - Preset Durations

    static let presets: [(String, TimeInterval)] = [
        ("5 min", 5 * 60),
        ("10 min", 10 * 60),
        ("15 min", 15 * 60),
        ("30 min", 30 * 60),
        ("45 min", 45 * 60),
        ("1 hour", 60 * 60),
        ("1.5 hours", 90 * 60),
        ("2 hours", 120 * 60),
    ]

    // MARK: - Public Methods

    /// Start the timer with a duration
    func start(duration: TimeInterval) {
        endTime = Date().addingTimeInterval(duration)
        endOfChapterTime = nil
        previousDuration = duration
        state = .active(remaining: duration)
    }

    /// Start timer to stop at end of current chapter
    func startEndOfChapter(chapterEndTime: TimeInterval) {
        endTime = nil
        endOfChapterTime = chapterEndTime
        state = .endOfChapter
    }

    /// Mark that we should stop at end of current chapter
    /// (chapter end time will be checked by the player)
    func setEndOfChapter() {
        endTime = nil
        endOfChapterTime = nil
        state = .endOfChapter
    }

    /// Cancel the timer
    func cancel() {
        endTime = nil
        endOfChapterTime = nil
        wasActiveBeforePause = false
        state = .inactive
    }

    /// Add time to the current timer (shake to extend)
    func extend(by seconds: TimeInterval = 300) { // 5 minutes default
        guard case .active = state, let currentEnd = endTime else { return }
        endTime = currentEnd.addingTimeInterval(seconds)
        updateRemainingTime()
    }

    /// Called every tick (during playback updates) to check timer
    func tick() {
        switch state {
        case .inactive:
            return

        case .active:
            updateRemainingTime()

            // Check if timer expired
            if let endTime = endTime, Date() >= endTime {
                fire()
            }

        case .endOfChapter:
            // End of chapter is checked by the player
            break
        }
    }

    /// Check if we should stop at end of chapter
    func checkEndOfChapter(currentTime: TimeInterval, chapterEndTime: TimeInterval) {
        guard case .endOfChapter = state else { return }

        // Stop within 1 second of chapter end
        if currentTime >= chapterEndTime - 1 {
            fire()
        }
    }

    /// Called when playback pauses
    func handlePause() {
        wasActiveBeforePause = state.isActive
    }

    /// Called when playback resumes
    func handleResume() {
        // Auto-restart if enabled and timer was previously active
        if autoRestartEnabled && wasActiveBeforePause && !state.isActive {
            start(duration: previousDuration > 0 ? previousDuration : autoRestartDuration)
        }
        wasActiveBeforePause = false
    }

    // MARK: - Private Methods

    private func fire() {
        state = .inactive
        endTime = nil
        endOfChapterTime = nil

        // Store that timer was active (for auto-restart)
        wasActiveBeforePause = true

        // Notify callback
        onTimerFired?()
    }

    private func updateRemainingTime() {
        guard let endTime = endTime else { return }

        let remaining = endTime.timeIntervalSinceNow
        if remaining > 0 {
            state = .active(remaining: remaining)
        }
    }

    // MARK: - Formatting

    /// Format remaining time for display
    var formattedRemaining: String {
        switch state {
        case .inactive:
            return "Off"
        case .endOfChapter:
            return "End of Chapter"
        case .active(let remaining):
            return Self.formatDuration(remaining)
        }
    }

    /// Format a duration for display
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}
