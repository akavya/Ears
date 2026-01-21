//
//  SpeedControlView.swift
//  Ears
//
//  Playback speed control
//

import SwiftUI

/// Playback speed control view.
///
/// Features:
/// - Preset speeds
/// - Fine-grained adjustment
/// - Visual speed indicator
struct SpeedControlView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSpeed: Float

    private let presets: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

    init() {
        _selectedSpeed = State(initialValue: 1.0)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Current speed display
                speedDisplay

                // Slider
                speedSlider

                // Presets
                presetsGrid

                Spacer()
            }
            .padding()
            .navigationTitle("Playback Speed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedSpeed = appState.audioPlayer.playbackRate
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Speed Display

    private var speedDisplay: some View {
        VStack(spacing: 8) {
            Text(String(format: "%.2fx", selectedSpeed))
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .monospacedDigit()

            // Time remaining at this speed
            if let book = appState.audioPlayer.currentBook {
                let remaining = book.duration - appState.audioPlayer.currentTime
                let adjustedRemaining = remaining / Double(selectedSpeed)

                Text("~\(formatDuration(adjustedRemaining)) remaining")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Slider

    private var speedSlider: some View {
        VStack(spacing: 8) {
            Slider(
                value: $selectedSpeed,
                in: 0.5...3.0,
                step: 0.05
            ) { editing in
                if !editing {
                    applySpeed()
                }
            }

            HStack {
                Text("0.5x")
                Spacer()
                Text("1x")
                Spacer()
                Text("2x")
                Spacer()
                Text("3x")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Presets

    private var presetsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Presets")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                ForEach(presets, id: \.self) { speed in
                    Button {
                        selectedSpeed = speed
                        applySpeed()
                        hapticFeedback()
                    } label: {
                        Text(formatSpeed(speed))
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                selectedSpeed == speed
                                    ? Color.accentColor
                                    : Color(.secondarySystemFill),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .foregroundStyle(selectedSpeed == speed ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private func applySpeed() {
        appState.audioPlayer.playbackRate = selectedSpeed
        appState.settings.defaultPlaybackSpeed = selectedSpeed
    }

    private func formatSpeed(_ speed: Float) -> String {
        if speed == Float(Int(speed)) {
            return String(format: "%.0fx", speed)
        } else if speed * 4 == Float(Int(speed * 4)) {
            return String(format: "%.2fx", speed)
        } else {
            return String(format: "%.1fx", speed)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func hapticFeedback() {
        guard appState.settings.hapticFeedbackEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Preview

#Preview {
    SpeedControlView()
        .environment(AppState())
}
