//
//  AccessibilityHelpers.swift
//  Ears
//
//  Accessibility utilities for VoiceOver and other assistive technologies
//

import SwiftUI

// MARK: - Accessibility Extensions

extension View {
    /// Add comprehensive accessibility for a book item
    func accessibleBook(_ book: Book) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(bookAccessibilityLabel(book))
            .accessibilityHint(bookAccessibilityHint(book))
            .accessibilityAddTraits(.isButton)
    }

    /// Add comprehensive accessibility for a chapter
    func accessibleChapter(_ chapter: Chapter, index: Int, isCurrent: Bool) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(chapterAccessibilityLabel(chapter, index: index))
            .accessibilityHint(isCurrent ? "Currently playing" : "Double tap to play")
            .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }

    /// Add accessibility for playback controls
    func accessiblePlaybackControl(_ label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }

    /// Add accessibility for a slider with time values
    func accessibleTimeSlider(currentTime: TimeInterval, duration: TimeInterval) -> some View {
        self
            .accessibilityLabel("Playback position")
            .accessibilityValue("\(formatTimeForAccessibility(currentTime)) of \(formatTimeForAccessibility(duration))")
    }
}

// MARK: - Accessibility Label Builders

private func bookAccessibilityLabel(_ book: Book) -> String {
    var parts: [String] = []

    parts.append(book.title)
    parts.append("by \(book.authorName)")

    if let narrator = book.narratorName, narrator != book.authorName {
        parts.append("read by \(narrator)")
    }

    if let series = book.seriesName {
        if let sequence = book.seriesSequence {
            parts.append("\(series) book \(sequence)")
        } else {
            parts.append("part of \(series) series")
        }
    }

    // Duration
    let hours = Int(book.duration) / 3600
    let minutes = (Int(book.duration) % 3600) / 60
    if hours > 0 {
        parts.append("\(hours) hours \(minutes) minutes")
    } else {
        parts.append("\(minutes) minutes")
    }

    // Progress
    if book.isFinished {
        parts.append("Finished")
    } else if book.progressPercent > 0 {
        let percent = Int(book.progressPercent * 100)
        parts.append("\(percent) percent complete")
    }

    return parts.joined(separator: ", ")
}

private func bookAccessibilityHint(_ book: Book) -> String {
    if book.isFinished {
        return "Double tap to listen again"
    } else if book.progressPercent > 0 {
        return "Double tap to continue listening"
    }
    return "Double tap to start listening"
}

private func chapterAccessibilityLabel(_ chapter: Chapter, index: Int) -> String {
    let duration = formatTimeForAccessibility(chapter.duration)
    return "Chapter \(index + 1): \(chapter.title), \(duration)"
}

private func formatTimeForAccessibility(_ seconds: TimeInterval) -> String {
    let hours = Int(seconds) / 3600
    let minutes = (Int(seconds) % 3600) / 60
    let secs = Int(seconds) % 60

    var parts: [String] = []

    if hours > 0 {
        parts.append("\(hours) hour\(hours == 1 ? "" : "s")")
    }
    if minutes > 0 {
        parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")")
    }
    if hours == 0 && secs > 0 {
        parts.append("\(secs) second\(secs == 1 ? "" : "s")")
    }

    return parts.joined(separator: " ")
}

// MARK: - VoiceOver Announcements

/// Helper for making VoiceOver announcements
enum VoiceOverAnnouncement {
    /// Announce playback started
    static func playbackStarted(title: String) {
        announce("Now playing: \(title)")
    }

    /// Announce playback paused
    static func playbackPaused() {
        announce("Paused")
    }

    /// Announce chapter change
    static func chapterChanged(title: String, index: Int) {
        announce("Chapter \(index + 1): \(title)")
    }

    /// Announce sleep timer set
    static func sleepTimerSet(duration: String) {
        announce("Sleep timer set for \(duration)")
    }

    /// Announce sleep timer cancelled
    static func sleepTimerCancelled() {
        announce("Sleep timer cancelled")
    }

    /// Announce download started
    static func downloadStarted(title: String) {
        announce("Downloading \(title)")
    }

    /// Announce download complete
    static func downloadComplete(title: String) {
        announce("\(title) downloaded")
    }

    /// Announce error
    static func error(_ message: String) {
        announce("Error: \(message)")
    }

    /// Make a VoiceOver announcement
    private static func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

// MARK: - Accessibility Focus State

/// Environment key for tracking accessibility focus
struct AccessibilityFocusedKey: EnvironmentKey {
    static let defaultValue: Binding<Bool>? = nil
}

extension EnvironmentValues {
    var accessibilityFocused: Binding<Bool>? {
        get { self[AccessibilityFocusedKey.self] }
        set { self[AccessibilityFocusedKey.self] = newValue }
    }
}

// MARK: - Dynamic Type Support

extension View {
    /// Scale a value based on Dynamic Type settings
    func scaledValue(_ value: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> CGFloat {
        UIFontMetrics(forTextStyle: textStyle.uiTextStyle).scaledValue(for: value)
    }
}

extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }
}

// MARK: - Reduce Motion

extension View {
    /// Apply animation only if Reduce Motion is not enabled
    func animationIfAllowed<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        self.modifier(ReduceMotionModifier(animation: animation, value: value))
    }
}

struct ReduceMotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation?
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

// MARK: - High Contrast

extension View {
    /// Increase contrast when accessibility setting is enabled
    func accessibilityHighContrast() -> some View {
        self.modifier(HighContrastModifier())
    }
}

struct HighContrastModifier: ViewModifier {
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor

    func body(content: Content) -> some View {
        content
            .contrast(differentiateWithoutColor ? 1.1 : 1.0)
    }
}
