//
//  LibraryViewModel.swift
//  Ears
//
//  View model for library browsing
//

import Foundation
import Observation

/// View model for the library view handling data loading and state management.
@Observable
final class LibraryViewModel {
    // MARK: - Properties

    /// Current library being displayed
    private(set) var library: Library?

    /// All loaded books
    private(set) var books: [Book] = []

    /// Books with progress for Continue Listening
    var continueListening: [Book] {
        books.filter { book in
            let progress = book.progressPercent
            return progress > 0 && progress < 0.95 && !book.isFinished
        }
        .sorted { ($0.progress?.lastUpdate ?? .distantPast) > ($1.progress?.lastUpdate ?? .distantPast) }
        .prefix(10)
        .map { $0 }
    }

    /// Available first letters for alphabet scrubber
    var availableLetters: [String] {
        let letters = Set(books.map { String($0.title.prefix(1)).uppercased() })
        return letters.sorted()
    }

    /// Loading state
    private(set) var isLoading = false

    /// Error message if any
    private(set) var errorMessage: String?

    /// Whether there are more books to load
    private(set) var hasMore = false

    // MARK: - Private Properties

    private var currentPage = 0
    private var currentSort = "media.metadata.title"
    private let pageSize = 50

    // MARK: - Public Methods

    /// Set the current library
    func setLibrary(_ library: Library) async {
        self.library = library
        self.books = []
        self.currentPage = 0
        self.hasMore = false
    }

    /// Load books from the API
    func loadBooks(sort: String? = nil) async {
        guard let library = library else { return }

        if let sort = sort {
            currentSort = sort
        }

        isLoading = true
        errorMessage = nil
        currentPage = 0

        do {
            let response = try await APIClient.shared.fetchLibraryItems(
                libraryId: library.id,
                page: currentPage,
                limit: pageSize,
                sort: currentSort
            )

            books = response.results
            hasMore = response.results.count == pageSize && books.count < response.total

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Load more books (pagination)
    func loadMore() async {
        guard let library = library, hasMore, !isLoading else { return }

        currentPage += 1
        isLoading = true

        do {
            let response = try await APIClient.shared.fetchLibraryItems(
                libraryId: library.id,
                page: currentPage,
                limit: pageSize,
                sort: currentSort
            )

            books.append(contentsOf: response.results)
            hasMore = response.results.count == pageSize && books.count < response.total

        } catch {
            // Revert page on error
            currentPage -= 1
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Refresh the library
    func refresh() async {
        await loadBooks()
    }

    /// Search books locally
    func search(query: String) -> [Book] {
        let lowercased = query.lowercased()
        return books.filter { book in
            book.title.lowercased().contains(lowercased) ||
            book.authorName.lowercased().contains(lowercased) ||
            (book.narratorName?.lowercased().contains(lowercased) ?? false) ||
            (book.seriesName?.lowercased().contains(lowercased) ?? false)
        }
    }

    /// Get books by first letter
    func books(startingWith letter: String) -> [Book] {
        books.filter { $0.title.prefix(1).uppercased() == letter }
    }
}
