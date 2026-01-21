//
//  Series.swift
//  Ears
//
//  Series model from Audiobookshelf API
//

import Foundation

/// Represents a book series
struct Series: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String?
    let addedAt: Date?
    let updatedAt: Date?
    let libraryId: String?

    // Included in some responses
    let books: [Book]?
    let numBooks: Int?

    /// Number of books in the series
    var bookCount: Int {
        numBooks ?? books?.count ?? 0
    }

    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Series, rhs: Series) -> Bool {
        lhs.id == rhs.id
    }
}

/// Response for /api/libraries/:id/series
struct SeriesResponse: Decodable {
    let results: [Series]
    let total: Int?
    let limit: Int?
    let page: Int?
}
