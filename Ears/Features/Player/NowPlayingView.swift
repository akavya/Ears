//
//  NowPlayingView.swift
//  Ears
//
//  Full-screen immersive player view
//

import SwiftUI

/// Full-screen now playing view with all playback controls.
///
/// Features:
/// - Large album artwork with blur background
/// - Playback progress with seeking
/// - Speed control
/// - Sleep timer
/// - Chapter navigation
/// - Accessible controls
struct NowPlayingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showChapters = false
    @State private var showSleepTimer = false
    @State private var showSpeedControl = false
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0

    private var player: AudioPlayer { appState.audioPlayer }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Blurred background
                backgroundView

                // Content
                VStack(spacing: 0) {
                    // Handle and dismiss
                    dismissHandle
                        .padding(.top, 8)

                    Spacer()

                    // Artwork
                    artworkView
                        .frame(maxWidth: geometry.size.width * 0.85)

                    Spacer()

                    // Info and controls
                    VStack(spacing: 24) {
                        // Title and author
                        titleSection

                        // Progress bar
                        progressSection

                        // Main controls
                        playbackControls

                        // Secondary controls
                        secondaryControls
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(appState.settings.bedroomModeEnabled ? .dark : nil)
        .sheet(isPresented: $showChapters) {
            if let book = player.currentBook {
                ChapterListView(
                    chapters: book.chapters,
                    currentChapterIndex: player.currentChapterIndex,
                    onSelect: { index in
                        Task {
                            await player.jumpToChapter(index)
                        }
                        showChapters = false
                    }
                )
            }
        }
        .sheet(isPresented: $showSleepTimer) {
            SleepTimerView()
        }
        .sheet(isPresented: $showSpeedControl) {
            SpeedControlView()
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            if let book = player.currentBook {
                AsyncImage(url: book.coverURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(.systemBackground)
                }
                .blur(radius: 60)
                .saturation(0.8)
            } else {
                Color(.systemBackground)
            }

            // Overlay for readability
            Color.black.opacity(appState.settings.bedroomModeEnabled ? 0.7 : 0.4)
        }
        .ignoresSafeArea()
    }

    // MARK: - Dismiss Handle

    private var dismissHandle: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(.white.opacity(0.5))
                .frame(width: 40, height: 5)

            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .accessibilityLabel("Dismiss player")
    }

    // MARK: - Artwork

    private var artworkView: some View {
        Group {
            if let book = player.currentBook {
                BookCover(book: book, size: .large)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray4))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(spacing: 8) {
            // Chapter title
            if let chapter = player.currentChapter {
                Text(chapter.title)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }

            // Book title
            Text(player.currentBook?.title ?? "Not Playing")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Author
            Text(player.currentBook?.authorName ?? "")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 8) {
            // Slider
            Slider(
                value: Binding(
                    get: { isDraggingSlider ? sliderValue : player.currentTime },
                    set: { newValue in
                        sliderValue = newValue
                        isDraggingSlider = true
                    }
                ),
                in: 0...max(player.duration, 1)
            ) { editing in
                if !editing && isDraggingSlider {
                    Task {
                        await player.seek(to: sliderValue)
                    }
                    isDraggingSlider = false
                }
            }
            .tint(.white)
            .accessibilityLabel("Playback position")
            .accessibilityValue(formatTime(player.currentTime))

            // Time labels
            HStack {
                Text(formatTime(isDraggingSlider ? sliderValue : player.currentTime))
                    .font(.caption.monospacedDigit())

                Spacer()

                Text("-\(formatTime(player.duration - (isDraggingSlider ? sliderValue : player.currentTime)))")
                    .font(.caption.monospacedDigit())
            }
            .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 40) {
            // Skip backward
            Button {
                Task {
                    await player.skipBackward(seconds: TimeInterval(appState.settings.skipBackwardInterval))
                }
                hapticFeedback()
            } label: {
                Image(systemName: "gobackward.\(appState.settings.skipBackwardInterval)")
                    .font(.system(size: 32))
            }
            .accessibilityLabel("Skip back \(appState.settings.skipBackwardInterval) seconds")

            // Previous chapter
            Button {
                Task {
                    await player.previousChapter()
                }
                hapticFeedback()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 28))
            }
            .accessibilityLabel("Previous chapter")

            // Play/Pause
            Button {
                player.togglePlayPause()
                hapticFeedback(.medium)
            } label: {
                Image(systemName: player.state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 72))
            }
            .accessibilityLabel(player.state.isPlaying ? "Pause" : "Play")

            // Next chapter
            Button {
                Task {
                    await player.nextChapter()
                }
                hapticFeedback()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 28))
            }
            .accessibilityLabel("Next chapter")

            // Skip forward
            Button {
                Task {
                    await player.skipForward(seconds: TimeInterval(appState.settings.skipForwardInterval))
                }
                hapticFeedback()
            } label: {
                Image(systemName: "goforward.\(appState.settings.skipForwardInterval)")
                    .font(.system(size: 32))
            }
            .accessibilityLabel("Skip forward \(appState.settings.skipForwardInterval) seconds")
        }
        .foregroundStyle(.white)
    }

    // MARK: - Secondary Controls

    private var secondaryControls: some View {
        HStack(spacing: 48) {
            // Chapters
            Button {
                showChapters = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.title3)
                    Text("Chapters")
                        .font(.caption2)
                }
            }
            .accessibilityLabel("Show chapters")

            // Speed
            Button {
                showSpeedControl = true
            } label: {
                VStack(spacing: 4) {
                    Text(String(format: "%.1fx", player.playbackRate))
                        .font(.headline.monospacedDigit())
                    Text("Speed")
                        .font(.caption2)
                }
            }
            .accessibilityLabel("Playback speed \(player.playbackRate)x")

            // Sleep timer
            Button {
                showSleepTimer = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: player.sleepTimer.state.isActive ? "moon.fill" : "moon")
                        .font(.title3)
                    Text(player.sleepTimer.state.isActive ? player.sleepTimer.formattedRemaining : "Sleep")
                        .font(.caption2)
                }
            }
            .accessibilityLabel(player.sleepTimer.state.isActive ? "Sleep timer: \(player.sleepTimer.formattedRemaining)" : "Set sleep timer")

            // AirPlay
            AirPlayButton()
                .frame(width: 44, height: 44)
        }
        .foregroundStyle(.white.opacity(0.9))
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard appState.settings.hapticFeedbackEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - AirPlay Button

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let routePickerView = AVRoutePickerView()
        routePickerView.tintColor = .white
        routePickerView.activeTintColor = .systemBlue
        return routePickerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

import AVKit

// MARK: - Preview

#Preview {
    NowPlayingView()
        .environment(AppState())
}
