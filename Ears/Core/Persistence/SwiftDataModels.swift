//
//  SwiftDataModels.swift
//  Ears
//
//  SwiftData models for local persistence
//

import Foundation
import SwiftData

/// Cached book for offline display and quick library loading
@Model
final class CachedBook {
    @Attribute(.unique) var id: String
    var libraryId: String
    var title: String
    var authorName: String
    var narratorName: String?
    var seriesName: String?
    var seriesSequence: String?
    var duration: TimeInterval
    var coverData: Data?
    var addedAt: Date
    var lastUpdated: Date

    // Progress
    var currentTime: TimeInterval
    var progressPercent: Double
    var isFinished: Bool
    var lastListened: Date?

    init(
        id: String,
        libraryId: String,
        title: String,
        authorName: String,
        narratorName: String? = nil,
        seriesName: String? = nil,
        seriesSequence: String? = nil,
        duration: TimeInterval,
        coverData: Data? = nil
    ) {
        self.id = id
        self.libraryId = libraryId
        self.title = title
        self.authorName = authorName
        self.narratorName = narratorName
        self.seriesName = seriesName
        self.seriesSequence = seriesSequence
        self.duration = duration
        self.coverData = coverData
        self.addedAt = Date()
        self.lastUpdated = Date()
        self.currentTime = 0
        self.progressPercent = 0
        self.isFinished = false
        self.lastListened = nil
    }

    /// Create from API Book model
    convenience init(from book: Book) {
        self.init(
            id: book.id,
            libraryId: book.libraryId,
            title: book.title,
            authorName: book.authorName,
            narratorName: book.narratorName,
            seriesName: book.seriesName,
            seriesSequence: book.seriesSequence,
            duration: book.duration
        )

        if let progress = book.progress {
            self.currentTime = progress.currentTime ?? 0
            self.progressPercent = progress.progress ?? 0
            self.isFinished = progress.isFinished ?? false
            self.lastListened = progress.lastUpdate
        }
    }

    /// Update from API Book model
    func update(from book: Book) {
        self.title = book.title
        self.authorName = book.authorName
        self.narratorName = book.narratorName
        self.seriesName = book.seriesName
        self.seriesSequence = book.seriesSequence
        self.duration = book.duration
        self.lastUpdated = Date()

        if let progress = book.progress {
            self.currentTime = progress.currentTime ?? 0
            self.progressPercent = progress.progress ?? 0
            self.isFinished = progress.isFinished ?? false
            self.lastListened = progress.lastUpdate
        }
    }
}

/// Persisted playback state for crash recovery
@Model
final class PlaybackStateRecord {
    @Attribute(.unique) var id: String
    var bookId: String
    var currentTime: TimeInterval
    var duration: TimeInterval
    var chapterIndex: Int?
    var playbackRate: Float
    var timestamp: Date

    init(bookId: String, currentTime: TimeInterval, duration: TimeInterval, chapterIndex: Int?, playbackRate: Float = 1.0) {
        self.id = UUID().uuidString
        self.bookId = bookId
        self.currentTime = currentTime
        self.duration = duration
        self.chapterIndex = chapterIndex
        self.playbackRate = playbackRate
        self.timestamp = Date()
    }
}

/// Downloaded file for offline playback
@Model
final class DownloadedFile {
    @Attribute(.unique) var id: String
    var bookId: String
    var bookTitle: String
    var authorName: String
    var fileName: String
    var filePath: String
    var fileSize: Int64
    var duration: TimeInterval
    var downloadedAt: Date
    var coverData: Data?

    /// Chapters stored as JSON
    var chaptersJSON: Data?

    init(
        bookId: String,
        bookTitle: String,
        authorName: String,
        fileName: String,
        filePath: String,
        fileSize: Int64,
        duration: TimeInterval,
        chapters: [Chapter]? = nil,
        coverData: Data? = nil
    ) {
        self.id = UUID().uuidString
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.authorName = authorName
        self.fileName = fileName
        self.filePath = filePath
        self.fileSize = fileSize
        self.duration = duration
        self.downloadedAt = Date()
        self.coverData = coverData

        if let chapters = chapters {
            self.chaptersJSON = try? JSONEncoder().encode(chapters)
        }
    }

    /// Get chapters from stored JSON
    var chapters: [Chapter] {
        guard let data = chaptersJSON else { return [] }
        return (try? JSONDecoder().decode([Chapter].self, from: data)) ?? []
    }

    /// File URL
    var fileURL: URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(filePath)
    }

    /// Whether the file still exists on disk
    var fileExists: Bool {
        guard let url = fileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
}

/// Saved server configuration
@Model
final class ServerConfig {
    @Attribute(.unique) var id: String
    var name: String
    var url: String
    var username: String?
    var lastUsed: Date
    var isDefault: Bool

    init(name: String, url: String, username: String? = nil, isDefault: Bool = false) {
        self.id = UUID().uuidString
        self.name = name
        self.url = url
        self.username = username
        self.lastUsed = Date()
        self.isDefault = isDefault
    }
}
