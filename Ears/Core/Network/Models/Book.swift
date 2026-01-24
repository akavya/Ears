//
//  Book.swift
//  Ears
//
//  Audiobook model from Audiobookshelf API
//

import Foundation

/// Represents an audiobook item
struct Book: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let ino: String?
    let libraryId: String
    let folderId: String?
    let path: String?
    let relPath: String?
    let isFile: Bool?
    let mtimeMs: Double?
    let ctimeMs: Double?
    let birthtimeMs: Double?
    let addedAt: Date?
    let updatedAt: Date?
    let lastScan: Date?
    let scanVersion: String?
    let isMissing: Bool?
    let isInvalid: Bool?
    let mediaType: String?
    let media: BookMedia?
    let numFiles: Int?
    let size: Int64?

    // MARK: - Computed Properties

    /// Book title
    var title: String {
        media?.metadata?.title ?? "Unknown Title"
    }

    /// Author name
    var authorName: String {
        media?.metadata?.authorName ?? "Unknown Author"
    }

    /// Narrator name
    var narratorName: String? {
        media?.metadata?.narratorName
    }

    /// Series info
    var seriesName: String? {
        media?.metadata?.seriesName
    }

    var seriesSequence: String? {
        media?.metadata?.series?.first?.sequence
    }

    /// Description/summary
    var description: String? {
        media?.metadata?.description
    }

    /// Publisher
    var publisher: String? {
        media?.metadata?.publisher
    }

    /// Publish year
    var publishedYear: String? {
        media?.metadata?.publishedYear
    }

    /// Genres
    var genres: [String] {
        media?.metadata?.genres ?? []
    }

    /// Total duration in seconds
    var duration: TimeInterval {
        media?.duration ?? 0
    }

    /// Chapters
    var chapters: [Chapter] {
        media?.chapters ?? []
    }

    /// Audio files
    var audioFiles: [AudioFile] {
        media?.audioFiles ?? []
    }

    /// Primary audio file URL (for single-file books)
    var audioFileURL: URL? {
        guard let baseURL = URL(string: UserDefaults.standard.string(forKey: "serverURL") ?? ""),
              let token = KeychainManager.shared.getToken() else {
            return nil
        }

        // Use the streaming endpoint
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/items/\(id)/play"), resolvingAgainstBaseURL: true)
        components?.queryItems = [URLQueryItem(name: "token", value: token)]
        return components?.url
    }

    /// Cover image URL
    var coverURL: URL? {
        guard let baseURL = URL(string: UserDefaults.standard.string(forKey: "serverURL") ?? "") else {
            return nil
        }
        return baseURL.appendingPathComponent("/api/items/\(id)/cover")
    }

    /// User progress
    var progress: MediaProgress? {
        media?.progress
    }

    /// Whether the book is finished
    var isFinished: Bool {
        progress?.isFinished ?? false
    }

    /// Current progress percentage (0-1)
    var progressPercent: Double {
        progress?.progress ?? 0
    }

    /// Current time position
    var currentTime: TimeInterval {
        progress?.currentTime ?? 0
    }

    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Book, rhs: Book) -> Bool {
        lhs.id == rhs.id
    }
}

/// Book media container
struct BookMedia: Codable, Sendable {
    let libraryItemId: String?
    let metadata: BookMetadata?
    let coverPath: String?
    let tags: [String]?
    let audioFiles: [AudioFile]?
    let chapters: [Chapter]?
    let duration: TimeInterval?
    let size: Int64?
    let tracks: [AudioTrack]?
    let missingParts: [String]?
    let ebookFile: EbookFile?

    // User-specific progress (included when using ?expanded=1)
    let progress: MediaProgress?

    private enum CodingKeys: String, CodingKey {
        case libraryItemId, metadata, coverPath, tags, audioFiles, chapters
        case duration, size, tracks, missingParts, ebookFile
        case progress = "userMediaProgress"
    }
}

/// Book metadata
struct BookMetadata: Codable, Sendable {
    let title: String?
    let subtitle: String?
    let authors: [AuthorReference]?
    let narrators: [String]?
    let series: [SeriesReference]?
    let genres: [String]?
    let publishedYear: String?
    let publishedDate: String?
    let publisher: String?
    let description: String?
    let isbn: String?
    let asin: String?
    let language: String?
    let explicit: Bool?
    let abridged: Bool?

    /// Combined author name
    var authorName: String {
        authors?.map(\.name).joined(separator: ", ") ?? "Unknown Author"
    }

    /// Combined narrator name
    var narratorName: String? {
        narrators?.joined(separator: ", ")
    }

    /// Series name
    var seriesName: String? {
        series?.first?.name
    }
}

/// Author reference in metadata
struct AuthorReference: Codable, Sendable {
    let id: String
    let name: String
}

/// Series reference in metadata
struct SeriesReference: Codable, Sendable {
    let id: String
    let name: String
    let sequence: String?
}

/// Chapter information
struct Chapter: Codable, Identifiable, Sendable {
    var id: Int { Int(start) }
    let start: TimeInterval
    let end: TimeInterval
    let title: String

    /// Chapter start time (alias for start)
    var startTime: TimeInterval { start }

    /// Chapter duration
    var duration: TimeInterval { end - start }
}

/// Audio file information
struct AudioFile: Codable, Identifiable, Sendable {
    let index: Int
    let ino: String
    let metadata: FileMetadata?
    let addedAt: Date?
    let updatedAt: Date?
    let trackNumFromMeta: Int?
    let discNumFromMeta: Int?
    let trackNumFromFilename: Int?
    let discNumFromFilename: Int?
    let manuallyVerified: Bool?
    let invalid: Bool?
    let exclude: Bool?
    let error: String?
    let format: String?
    let duration: TimeInterval?
    let bitRate: Int?
    let language: String?
    let codec: String?
    let timeBase: String?
    let channels: Int?
    let channelLayout: String?
    let mimeType: String?

    var id: String { ino }
}

/// File metadata
struct FileMetadata: Codable, Sendable {
    let filename: String?
    let ext: String?
    let path: String?
    let relPath: String?
    let size: Int64?
    let mtimeMs: Double?
    let ctimeMs: Double?
    let birthtimeMs: Double?
}

/// Audio track
struct AudioTrack: Codable, Sendable {
    let index: Int?
    let startOffset: TimeInterval?
    let duration: TimeInterval?
    let title: String?
    let contentUrl: String?
    let mimeType: String?
    let metadata: FileMetadata?
}

/// Ebook file
struct EbookFile: Codable, Sendable {
    let ino: String?
    let metadata: FileMetadata?
    let ebookFormat: String?
    let addedAt: Date?
    let updatedAt: Date?
}

/// User progress on a book
struct MediaProgress: Codable, Identifiable, Sendable {
    let id: String?
    let libraryItemId: String?
    let episodeId: String?
    let mediaItemId: String?
    let mediaItemType: String?
    let duration: TimeInterval?
    let progress: Double?
    let currentTime: TimeInterval?
    let isFinished: Bool?
    let hideFromContinueListening: Bool?
    let lastUpdate: Date?
    let startedAt: Date?
    let finishedAt: Date?
}
