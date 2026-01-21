//
//  SearchResponse.swift
//  Ears
//
//  Search response models from Audiobookshelf API
//

import Foundation

/// Response from library search
struct SearchResponse: Decodable {
    let book: [SearchBookResult]?
    let podcast: [SearchPodcastResult]?
    let narrators: [SearchNarratorResult]?
    let authors: [SearchAuthorResult]?
    let series: [SearchSeriesResult]?
    let tags: [SearchTagResult]?

    /// All book results
    var books: [Book] {
        book?.map(\.libraryItem) ?? []
    }
}

/// Book search result
struct SearchBookResult: Decodable {
    let libraryItem: Book
    let matchKey: String?
    let matchText: String?
}

/// Podcast search result
struct SearchPodcastResult: Decodable {
    let libraryItem: Book
    let matchKey: String?
    let matchText: String?
}

/// Narrator search result
struct SearchNarratorResult: Decodable {
    let name: String
}

/// Author search result
struct SearchAuthorResult: Decodable {
    let id: String
    let name: String
}

/// Series search result
struct SearchSeriesResult: Decodable {
    let series: Series
    let books: [Book]?
}

/// Tag search result
struct SearchTagResult: Decodable {
    let name: String
}
