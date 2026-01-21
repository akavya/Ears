//
//  SettingsView.swift
//  Ears
//
//  App settings and preferences
//

import SwiftUI

/// Main settings view with all app preferences.
///
/// Sections:
/// - Account & Server
/// - Playback
/// - Downloads
/// - Appearance
/// - Accessibility
/// - About
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                // Account
                accountSection

                // Playback
                playbackSection

                // Downloads
                downloadsSection

                // Appearance
                appearanceSection

                // Accessibility
                accessibilitySection

                // About
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section("Account") {
            if let user = appState.currentUser {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading) {
                        Text(user.username)
                            .font(.headline)

                        if let url = appState.serverURL {
                            Text(url.host ?? url.absoluteString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Button("Sign Out", role: .destructive) {
                Task {
                    await appState.logout()
                }
            }
        }
    }

    // MARK: - Playback Section

    private var playbackSection: some View {
        Section("Playback") {
            @Bindable var settings = appState.settings

            // Auto-play on launch
            Toggle("Auto-play on Launch", isOn: $settings.autoPlayOnLaunch)

            // Default speed
            NavigationLink {
                DefaultSpeedPicker(speed: $settings.defaultPlaybackSpeed)
            } label: {
                HStack {
                    Text("Default Speed")
                    Spacer()
                    Text(String(format: "%.1fx", settings.defaultPlaybackSpeed))
                        .foregroundStyle(.secondary)
                }
            }

            // Skip intervals
            NavigationLink {
                SkipIntervalPicker(
                    forwardInterval: $settings.skipForwardInterval,
                    backwardInterval: $settings.skipBackwardInterval
                )
            } label: {
                HStack {
                    Text("Skip Intervals")
                    Spacer()
                    Text("\(settings.skipBackwardInterval)s / \(settings.skipForwardInterval)s")
                        .foregroundStyle(.secondary)
                }
            }

            // Sleep timer
            Toggle("Auto-restart Sleep Timer", isOn: $settings.sleepTimerAutoRestart)
        }
    }

    // MARK: - Downloads Section

    private var downloadsSection: some View {
        Section("Downloads") {
            @Bindable var settings = appState.settings

            Toggle("Auto-download Next in Series", isOn: $settings.autoDownloadNextInSeries)

            Toggle("Auto-delete Completed Books", isOn: $settings.autoDeleteCompleted)
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section("Appearance") {
            @Bindable var settings = appState.settings

            Toggle("Bedroom Mode", isOn: $settings.bedroomModeEnabled)

            if settings.bedroomModeEnabled {
                Toggle("Auto-enable at Night", isOn: $settings.autoEnableBedroomMode)
            }
        }
    }

    // MARK: - Accessibility Section

    private var accessibilitySection: some View {
        Section("Accessibility") {
            @Bindable var settings = appState.settings

            Toggle("Haptic Feedback", isOn: $settings.hapticFeedbackEnabled)

            NavigationLink("VoiceOver Settings") {
                VoiceOverSettingsView()
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://github.com/akavya/Ears")!) {
                HStack {
                    Text("GitHub Repository")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Link(destination: URL(string: "https://www.audiobookshelf.org/")!) {
                HStack {
                    Text("Audiobookshelf")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Default Speed Picker

struct DefaultSpeedPicker: View {
    @Binding var speed: Float
    @Environment(\.dismiss) private var dismiss

    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.1, 1.2, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

    var body: some View {
        List {
            ForEach(speeds, id: \.self) { s in
                Button {
                    speed = s
                    dismiss()
                } label: {
                    HStack {
                        Text(String(format: "%.2fx", s))
                        Spacer()
                        if speed == s {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.accentColor)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("Default Speed")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Skip Interval Picker

struct SkipIntervalPicker: View {
    @Binding var forwardInterval: Int
    @Binding var backwardInterval: Int

    private let intervals = [5, 10, 15, 20, 30, 45, 60, 90]

    var body: some View {
        List {
            Section("Skip Forward") {
                ForEach(intervals, id: \.self) { interval in
                    Button {
                        forwardInterval = interval
                    } label: {
                        HStack {
                            Text("\(interval) seconds")
                            Spacer()
                            if forwardInterval == interval {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.accentColor)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }

            Section("Skip Backward") {
                ForEach(intervals, id: \.self) { interval in
                    Button {
                        backwardInterval = interval
                    } label: {
                        HStack {
                            Text("\(interval) seconds")
                            Spacer()
                            if backwardInterval == interval {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.accentColor)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle("Skip Intervals")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - VoiceOver Settings

struct VoiceOverSettingsView: View {
    var body: some View {
        List {
            Section {
                Text("Ears is designed with accessibility in mind. All controls are properly labeled for VoiceOver.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Tips") {
                Label("Swipe up or down on the player to adjust volume", systemImage: "speaker.wave.2")
                Label("Double-tap and hold to scrub through chapters", systemImage: "hand.tap")
                Label("Magic Tap (two-finger double-tap) plays/pauses", systemImage: "hand.tap")
            }
            .font(.subheadline)

            Section {
                Link(destination: URL(string: "https://support.apple.com/guide/iphone/turn-on-and-practice-voiceover-iph3e2e415f/ios")!) {
                    Label("Learn More About VoiceOver", systemImage: "questionmark.circle")
                }
            }
        }
        .navigationTitle("VoiceOver")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(AppState())
}
