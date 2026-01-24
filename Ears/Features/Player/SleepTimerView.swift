//
//  SleepTimerView.swift
//  Ears
//
//  Sleep timer configuration with auto-restart option
//

import SwiftUI

/// Sleep timer configuration view.
///
/// Features:
/// - Preset durations
/// - End of chapter option
/// - Auto-restart toggle (like BookPlayer)
/// - Custom duration picker
/// - Shake to extend indicator
struct SleepTimerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var showCustomPicker = false
    @State private var customMinutes = 15

    private var sleepTimer: SleepTimer { appState.audioPlayer.sleepTimer }

    var body: some View {
        NavigationStack {
            List {
                // Current status
                if sleepTimer.state.isActive {
                    currentTimerSection
                }

                // Presets
                presetsSection

                // Auto-restart
                autoRestartSection

                // Tips
                tipsSection
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCustomPicker) {
                customDurationPicker
            }
        }
    }

    // MARK: - Current Timer Section

    private var currentTimerSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Timer Active")
                        .font(.headline)

                    Text(sleepTimer.formattedRemaining)
                        .font(.title2.monospacedDigit().bold())
                        .foregroundStyle(Color.accentColor)
                }

                Spacer()

                // Extend button
                Button {
                    sleepTimer.extend(by: 300) // 5 minutes
                    hapticFeedback()
                } label: {
                    Label("+5 min", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 4)

            // Cancel button
            Button("Cancel Timer", role: .destructive) {
                sleepTimer.cancel()
                hapticFeedback()
            }
        } header: {
            Text("Active Timer")
        }
    }

    // MARK: - Presets Section

    private var presetsSection: some View {
        Section {
            // End of chapter
            Button {
                setEndOfChapter()
            } label: {
                HStack {
                    Label("End of Chapter", systemImage: "bookmark")
                    Spacer()
                    if case .endOfChapter = sleepTimer.state {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .foregroundStyle(.primary)

            // Preset durations
            ForEach(SleepTimer.presets, id: \.1) { preset in
                Button {
                    sleepTimer.start(duration: preset.1)
                    hapticFeedback()
                    dismiss()
                } label: {
                    HStack {
                        Text(preset.0)
                        Spacer()
                        if case .active(let remaining) = sleepTimer.state,
                           abs(remaining - preset.1) < 60 {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }

            // Custom
            Button {
                showCustomPicker = true
            } label: {
                HStack {
                    Label("Custom", systemImage: "slider.horizontal.3")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
        } header: {
            Text("Set Timer")
        }
    }

    // MARK: - Auto-restart Section

    private var autoRestartSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { sleepTimer.autoRestartEnabled },
                set: { newValue in
                    sleepTimer.autoRestartEnabled = newValue
                    appState.settings.sleepTimerAutoRestart = newValue
                }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto-restart on Resume")
                    Text("Timer restarts when you resume playback")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Behavior")
        } footer: {
            Text("Like BookPlayer, the sleep timer will automatically restart when you resume playback via headphones or the app.")
        }
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        Section {
            Label {
                Text("Shake your device to add 5 minutes")
            } icon: {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        } header: {
            Text("Tips")
        }
    }

    // MARK: - Custom Duration Picker

    private var customDurationPicker: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Set Custom Duration")
                    .font(.headline)

                Picker("Minutes", selection: $customMinutes) {
                    ForEach([5, 10, 15, 20, 25, 30, 45, 60, 90, 120], id: \.self) { minutes in
                        Text(formatMinutes(minutes)).tag(minutes)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)

                Button("Start Timer") {
                    sleepTimer.start(duration: TimeInterval(customMinutes * 60))
                    hapticFeedback()
                    showCustomPicker = false
                    dismiss()
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        showCustomPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func setEndOfChapter() {
        guard let book = appState.audioPlayer.currentBook,
              let currentChapter = appState.audioPlayer.currentChapter else {
            return
        }

        let currentIndex = appState.audioPlayer.currentChapterIndex
        let chapterEndTime = currentIndex < book.chapters.count - 1
            ? book.chapters[currentIndex + 1].startTime
            : book.duration

        sleepTimer.startEndOfChapter(chapterEndTime: chapterEndTime)
        hapticFeedback()
        dismiss()
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours) hour\(hours > 1 ? "s" : "")"
            }
            return "\(hours)h \(mins)m"
        }
        return "\(minutes) minutes"
    }

    private func hapticFeedback() {
        guard appState.settings.hapticFeedbackEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Preview

#Preview {
    SleepTimerView()
        .environment(AppState())
}
