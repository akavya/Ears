//
//  BookDetailView.swift
//  Ears
//
//  Detailed view for a single audiobook
//

import SwiftUI

/// Detailed view showing all information about an audiobook.
///
/// Features:
/// - Large cover with blur background
/// - Play/resume button
/// - Download for offline
/// - Chapter list
/// - Author and narrator links
/// - Series navigation
struct BookDetailView: View {
    let book: Book

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var showChapters = false
    @State private var showDownloadOptions = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero section with cover
                heroSection

                // Content
                VStack(spacing: 24) {
                    // Action buttons
                    actionButtons

                    // Book info
                    bookInfo

                    // Chapters
                    if !book.chapters.isEmpty {
                        chaptersSection
                    }

                    // Description
                    if let description = book.description, !description.isEmpty {
                        descriptionSection(description)
                    }
                }
                .padding()
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showDownloadOptions = true
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle")
                    }

                    Button {
                        // Mark as finished
                    } label: {
                        Label("Mark as Finished", systemImage: "checkmark.circle")
                    }

                    Button {
                        // Add to queue
                    } label: {
                        Label("Add to Queue", systemImage: "text.badge.plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showChapters) {
            ChapterListView(
                chapters: book.chapters,
                currentChapterIndex: 0,
                onSelect: { index in
                    Task {
                        await playFromChapter(index)
                    }
                }
            )
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Blurred background
            AsyncImage(url: book.coverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color(.systemGray4)
            }
            .frame(height: 300)
            .clipped()
            .blur(radius: 20)
            .overlay(Color.black.opacity(0.3))

            // Cover and title
            VStack(spacing: 16) {
                BookCover(book: book, size: .large)
                    .frame(width: 200, height: 200)
                    .shadow(radius: 10)

                VStack(spacing: 4) {
                    Text(book.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)

                    if let subtitle = book.media?.metadata?.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .padding()
            .padding(.bottom, 20)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Play button
            Button {
                Task {
                    await play()
                }
            } label: {
                Label(playButtonTitle, systemImage: playButtonIcon)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)

            // Download button
            Button {
                showDownloadOptions = true
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.title2)
            }
            .buttonStyle(.bordered)
            .frame(width: 50, height: 50)
        }
    }

    private var playButtonTitle: String {
        if book.progressPercent > 0 && !book.isFinished {
            return "Resume"
        } else if book.isFinished {
            return "Play Again"
        }
        return "Play"
    }

    private var playButtonIcon: String {
        "play.fill"
    }

    // MARK: - Book Info

    private var bookInfo: some View {
        VStack(spacing: 16) {
            // Author
            infoRow(title: "Author", value: book.authorName, systemImage: "person")

            // Narrator
            if let narrator = book.narratorName {
                infoRow(title: "Narrator", value: narrator, systemImage: "mic")
            }

            // Series
            if let series = book.seriesName {
                let sequence = book.seriesSequence.map { " #\($0)" } ?? ""
                infoRow(title: "Series", value: series + sequence, systemImage: "books.vertical")
            }

            // Duration
            infoRow(title: "Duration", value: formatDuration(book.duration), systemImage: "clock")

            // Publisher
            if let publisher = book.publisher {
                infoRow(title: "Publisher", value: publisher, systemImage: "building.2")
            }

            // Year
            if let year = book.publishedYear {
                infoRow(title: "Published", value: year, systemImage: "calendar")
            }

            // Genres
            if !book.genres.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Genres")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 8) {
                        ForEach(book.genres, id: \.self) { genre in
                            Text(genre)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.secondary.opacity(0.2), in: Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func infoRow(title: String, value: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.subheadline)

            Spacer()
        }
    }

    // MARK: - Chapters

    private var chaptersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Chapters")
                    .font(.headline)

                Spacer()

                Button("View All") {
                    showChapters = true
                }
                .font(.subheadline)
            }

            VStack(spacing: 0) {
                ForEach(Array(book.chapters.prefix(5).enumerated()), id: \.element.id) { index, chapter in
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        Text(chapter.title)
                            .font(.subheadline)
                            .lineLimit(1)

                        Spacer()

                        Text(formatDuration(chapter.duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)

                    if index < min(4, book.chapters.count - 1) {
                        Divider()
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Description

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.headline)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func play() async {
        isLoading = true

        do {
            try await appState.audioPlayer.play(
                book: book,
                startPosition: book.isFinished ? 0 : book.currentTime
            )
            appState.showingFullPlayer = true
        } catch {
            // Show error
        }

        isLoading = false
    }

    private func playFromChapter(_ index: Int) async {
        showChapters = false

        do {
            let chapter = book.chapters[index]
            try await appState.audioPlayer.play(book: book, startPosition: chapter.startTime)
            appState.showingFullPlayer = true
        } catch {
            // Show error
        }
    }
}

// MARK: - Flow Layout

/// A simple flow layout for tags/genres
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, spacing: spacing, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, spacing: spacing, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, spacing: CGFloat, subviews: Subviews) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BookDetailView(book: .preview)
            .environment(AppState())
    }
}
