//
//  Library.swift
//  Ears
//
//  Library model from Audiobookshelf API
//

import Foundation

/// Represents an Audiobookshelf library
struct Library: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let folders: [LibraryFolder]?
    let displayOrder: Int
    let icon: String
    let mediaType: String
    let provider: String?
    let settings: LibrarySettings?
    let createdAt: Date?
    let lastUpdate: Date?

    /// Whether this is an audiobook library
    var isAudiobookLibrary: Bool {
        mediaType == "book"
    }

    /// Whether this is a podcast library
    var isPodcastLibrary: Bool {
        mediaType == "podcast"
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Library, rhs: Library) -> Bool {
        lhs.id == rhs.id
    }
}

/// Library folder
struct LibraryFolder: Codable, Identifiable, Sendable {
    let id: String
    let fullPath: String
    let libraryId: String?
    let addedAt: Date?
}

/// Library settings
struct LibrarySettings: Codable, Sendable {
    let coverAspectRatio: Int?
    let disableWatcher: Bool?
    let skipMatchingMediaWithAsin: Bool?
    let skipMatchingMediaWithIsbn: Bool?
    let autoScanCronExpression: String?
}

// MARK: - API Responses

/// Response for /api/libraries
struct LibrariesResponse: Decodable {
    let libraries: [Library]
}

/// Response for /api/libraries/:id/items
struct LibraryItemsResponse: Decodable {
    let results: [Book]
    let total: Int
    let limit: Int
    let page: Int
    let sortBy: String?
    let sortDesc: Bool?
    let filterBy: String?
    let mediaType: String?
    let minified: Bool?
    let collapseseries: Bool?
}
