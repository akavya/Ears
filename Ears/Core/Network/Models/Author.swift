//
//  Author.swift
//  Ears
//
//  Author model from Audiobookshelf API
//

import Foundation

/// Represents an author
struct Author: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let asin: String?
    let name: String
    let description: String?
    let imagePath: String?
    let addedAt: Date?
    let updatedAt: Date?
    let libraryId: String?

    // Included when fetching with ?include=items
    let libraryItems: [Book]?
    let numBooks: Int?

    /// Number of books by this author
    var bookCount: Int {
        numBooks ?? libraryItems?.count ?? 0
    }

    /// Author image URL
    func imageURL(baseURL: URL) -> URL? {
        guard imagePath != nil else { return nil }
        return baseURL.appendingPathComponent("/api/authors/\(id)/image")
    }

    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Author, rhs: Author) -> Bool {
        lhs.id == rhs.id
    }
}

/// Response for /api/libraries/:id/authors
struct AuthorsResponse: Decodable {
    let authors: [Author]
}
