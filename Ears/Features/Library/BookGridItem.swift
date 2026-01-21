//
//  BookGridItem.swift
//  Ears
//
//  Grid item view for displaying a book in the library
//

import SwiftUI

/// A grid item displaying a book with cover, title, and author.
struct BookGridItem: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover image
            BookCover(book: book, size: .medium)
                .overlay(alignment: .bottomTrailing) {
                    if book.progressPercent > 0 {
                        progressIndicator
                    }
                }

            // Title
            Text(book.title)
                .font(.subheadline.bold())
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Author
            Text(book.authorName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // Narrator (if different from author)
            if let narrator = book.narratorName, narrator != book.authorName {
                Text("Read by \(narrator)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressIndicator: some View {
        Group {
            if book.isFinished {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .background(Circle().fill(.white))
            } else {
                CircularProgressView(progress: book.progressPercent)
            }
        }
        .padding(6)
    }
}

/// A list item for displaying a book.
struct BookListItem: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            // Cover
            BookCover(book: book, size: .small)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(book.authorName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let narrator = book.narratorName, narrator != book.authorName {
                    Text("Read by \(narrator)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Duration
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(formatDuration(book.duration))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Progress
            if book.isFinished {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            } else if book.progressPercent > 0 {
                CircularProgressView(progress: book.progressPercent)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.vertical, 4)
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
}

/// Card for continue listening section
struct ContinueListeningCard: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BookCover(book: book, size: .medium)
                .overlay(alignment: .center) {
                    // Play button overlay
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                }

            Text(book.title)
                .font(.subheadline.bold())
                .lineLimit(1)

            // Progress bar
            ProgressView(value: book.progressPercent)
                .tint(.accentColor)

            // Time remaining
            Text(timeRemaining)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 150)
    }

    private var timeRemaining: String {
        let remaining = book.duration * (1 - book.progressPercent)
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        } else {
            return "\(minutes)m left"
        }
    }
}

/// Circular progress indicator
struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.3), lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.system(size: 8, weight: .bold))
        }
        .frame(width: 28, height: 28)
    }
}

// MARK: - Book Cover

/// Reusable book cover view with caching
struct BookCover: View {
    let book: Book
    let size: CoverSize

    enum CoverSize {
        case small  // 60x60
        case medium // 150x150
        case large  // Full width

        var dimension: CGFloat {
            switch self {
            case .small: return 60
            case .medium: return 150
            case .large: return 300
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 8
            case .large: return 12
            }
        }
    }

    var body: some View {
        AsyncImage(url: book.coverURL) { phase in
            switch phase {
            case .empty:
                placeholder
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                placeholder
            @unknown default:
                placeholder
            }
        }
        .frame(width: size == .large ? nil : size.dimension, height: size.dimension)
        .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }

    private var placeholder: some View {
        ZStack {
            Color(.systemGray5)

            VStack(spacing: 4) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: size == .small ? 20 : 40))
                    .foregroundStyle(.secondary)

                if size != .small {
                    Text(book.title.prefix(20))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        BookGridItem(book: .preview)
            .frame(width: 150)

        BookListItem(book: .preview)
            .padding()
    }
}

// MARK: - Preview Helper

extension Book {
    static var preview: Book {
        Book(
            id: "preview",
            ino: "preview",
            libraryId: "lib1",
            folderId: nil,
            path: nil,
            relPath: nil,
            isFile: false,
            mtimeMs: nil,
            ctimeMs: nil,
            birthtimeMs: nil,
            addedAt: Date(),
            updatedAt: Date(),
            lastScan: nil,
            scanVersion: nil,
            isMissing: false,
            isInvalid: false,
            mediaType: "book",
            media: BookMedia(
                libraryItemId: "preview",
                metadata: BookMetadata(
                    title: "The Great Gatsby",
                    subtitle: nil,
                    authors: [AuthorReference(id: "a1", name: "F. Scott Fitzgerald")],
                    narrators: ["Jake Gyllenhaal"],
                    series: nil,
                    genres: ["Classic", "Fiction"],
                    publishedYear: "1925",
                    publishedDate: nil,
                    publisher: "Scribner",
                    description: "A classic novel about the American Dream.",
                    isbn: nil,
                    asin: nil,
                    language: "en",
                    explicit: false,
                    abridged: false
                ),
                coverPath: nil,
                tags: nil,
                audioFiles: nil,
                chapters: [],
                duration: 18000,
                size: 500000000,
                tracks: nil,
                missingParts: nil,
                ebookFile: nil,
                progress: MediaProgress(
                    id: "p1",
                    libraryItemId: "preview",
                    episodeId: nil,
                    duration: 18000,
                    progress: 0.35,
                    currentTime: 6300,
                    isFinished: false,
                    hideFromContinueListening: false,
                    lastUpdate: Date(),
                    startedAt: Date(),
                    finishedAt: nil
                )
            ),
            numFiles: 1,
            size: 500000000
        )
    }
}
