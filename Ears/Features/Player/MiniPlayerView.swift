//
//  MiniPlayerView.swift
//  Ears
//
//  Compact mini player shown at bottom of screen
//

import SwiftUI

/// Compact mini player that appears above the tab bar during playback.
///
/// Features:
/// - Dismissible with swipe down
/// - Tap to expand to full player
/// - Play/pause control
/// - Progress indicator
/// - Smooth animations
struct MiniPlayerView: View {
    @Environment(AppState.self) private var appState
    @State private var dragOffset: CGFloat = 0
    @State private var showFullPlayer = false

    private var player: AudioPlayer { appState.audioPlayer }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar at top
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * player.duration > 0 ? (player.currentTime / player.duration) : 0)
            }
            .frame(height: 3)
            .background(Color(.systemGray5))

            // Content
            HStack(spacing: 12) {
                // Cover
                if let book = player.currentBook {
                    BookCover(book: book, size: .small)
                        .frame(width: 48, height: 48)
                }

                // Title and chapter
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentBook?.title ?? "Not Playing")
                        .font(.subheadline.bold())
                        .lineLimit(1)

                    if let chapter = player.currentChapter {
                        Text(chapter.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(player.currentBook?.authorName ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Play/Pause
                Button {
                    player.togglePlayPause()
                    hapticFeedback()
                } label: {
                    Image(systemName: player.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(player.state.isPlaying ? "Pause" : "Play")

                // Skip forward
                Button {
                    Task {
                        await player.skipForward(seconds: TimeInterval(appState.settings.skipForwardInterval))
                    }
                    hapticFeedback()
                } label: {
                    Image(systemName: "goforward.\(appState.settings.skipForwardInterval)")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Skip forward")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow dragging down or small up drag
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    } else if value.translation.height > -50 {
                        dragOffset = value.translation.height * 0.3
                    }
                }
                .onEnded { value in
                    // Dismiss if dragged down enough
                    if value.translation.height > 100 || value.predictedEndTranslation.height > 200 {
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = 200
                        }
                        // Stop playback after animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            player.pause()
                        }
                    }
                    // Expand if dragged up
                    else if value.translation.height < -50 {
                        showFullPlayer = true
                    }

                    withAnimation(.spring(response: 0.3)) {
                        dragOffset = 0
                    }
                }
        )
        .onTapGesture {
            showFullPlayer = true
        }
        .fullScreenCover(isPresented: $showFullPlayer) {
            NowPlayingView()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mini player: \(player.currentBook?.title ?? "Not playing")")
        .accessibilityHint("Tap to expand, swipe down to dismiss")
    }

    private func hapticFeedback() {
        guard appState.settings.hapticFeedbackEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        MiniPlayerView()
    }
    .environment(AppState())
}
