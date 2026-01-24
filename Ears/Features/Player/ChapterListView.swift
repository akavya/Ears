//
//  ChapterListView.swift
//  Ears
//
//  Chapter list for navigation within a book
//

import SwiftUI

/// List of chapters allowing navigation within the audiobook.
///
/// Features:
/// - Current chapter highlighting
/// - Chapter durations
/// - Smooth scrolling to current chapter
/// - Search/filter chapters
struct ChapterListView: View {
    let chapters: [Chapter]
    let currentChapterIndex: Int
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var scrollPosition: Int?

    private var filteredChapters: [(index: Int, chapter: Chapter)] {
        let indexed = chapters.enumerated().map { (index: $0.offset, chapter: $0.element) }

        if searchText.isEmpty {
            return indexed
        }

        return indexed.filter { $0.chapter.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredChapters, id: \.index) { item in
                    ChapterRow(
                        chapter: item.chapter,
                        index: item.index,
                        isCurrent: item.index == currentChapterIndex,
                        onTap: {
                            onSelect(item.index)
                        }
                    )
                    .id(item.index)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search chapters")
            .scrollPosition(id: $scrollPosition, anchor: .center)
            .onAppear {
                // Scroll to current chapter
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        scrollPosition = currentChapterIndex
                    }
                }
            }
        }
    }
}

// MARK: - Chapter Row

struct ChapterRow: View {
    let chapter: Chapter
    let index: Int
    let isCurrent: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Chapter number
                Text("\(index + 1)")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(isCurrent ? .white : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(isCurrent ? Color.accentColor : Color(.systemGray5))
                    )

                // Title
                VStack(alignment: .leading, spacing: 2) {
                    Text(chapter.title)
                        .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent ? Color.accentColor : Color.primary)
                        .lineLimit(2)

                    Text(formatDuration(chapter.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Now playing indicator
                if isCurrent {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .symbolEffect(.variableColor.iterative)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isCurrent ? Color.accentColor.opacity(0.1) : nil)
        .accessibilityLabel("Chapter \(index + 1): \(chapter.title), \(formatDuration(chapter.duration))")
        .accessibilityHint(isCurrent ? "Currently playing" : "Double tap to play")
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60

        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        }

        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Preview

#Preview {
    ChapterListView(
        chapters: [
            Chapter(start: 0, end: 1200, title: "Chapter 1: The Beginning"),
            Chapter(start: 1200, end: 2400, title: "Chapter 2: The Journey"),
            Chapter(start: 2400, end: 3600, title: "Chapter 3: The Destination"),
        ],
        currentChapterIndex: 1,
        onSelect: { _ in }
    )
}
