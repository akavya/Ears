//
//  SearchView.swift
//  Ears
//
//  Fast local and server search
//

import SwiftUI

/// Search view with both local and server search capabilities.
///
/// Features:
/// - Instant local search (cached books)
/// - Server search fallback
/// - Search history
/// - Category filtering (books, authors, series)
struct SearchView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: SearchResults = .empty
    @State private var searchHistory: [String] = []
    @State private var selectedCategory: SearchCategory = .all

    enum SearchCategory: String, CaseIterable {
        case all = "All"
        case books = "Books"
        case authors = "Authors"
        case series = "Series"
        case narrators = "Narrators"
    }

    struct SearchResults {
        var books: [Book] = []
        var authors: [SearchAuthorResult] = []
        var series: [SearchSeriesResult] = []
        var narrators: [SearchNarratorResult] = []

        var isEmpty: Bool {
            books.isEmpty && authors.isEmpty && series.isEmpty && narrators.isEmpty
        }

        static let empty = SearchResults()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category picker
                categoryPicker
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                // Results
                if searchText.isEmpty {
                    recentSearches
                } else if isSearching {
                    loadingView
                } else if searchResults.isEmpty {
                    emptyResults
                } else {
                    searchResultsList
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search books, authors, series..."
            )
            .onChange(of: searchText) { _, newValue in
                performSearch(query: newValue)
            }
            .onAppear {
                loadSearchHistory()
            }
        }
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchCategory.allCases, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category.rawValue)
                            .font(.subheadline.weight(selectedCategory == category ? .semibold : .regular))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedCategory == category
                                    ? Color.accentColor
                                    : Color(.secondarySystemFill),
                                in: Capsule()
                            )
                            .foregroundStyle(selectedCategory == category ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Recent Searches

    private var recentSearches: some View {
        List {
            if !searchHistory.isEmpty {
                Section("Recent Searches") {
                    ForEach(searchHistory, id: \.self) { query in
                        Button {
                            searchText = query
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.secondary)
                                Text(query)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete { indexSet in
                        searchHistory.remove(atOffsets: indexSet)
                        saveSearchHistory()
                    }
                }

                Section {
                    Button("Clear History", role: .destructive) {
                        searchHistory.removeAll()
                        saveSearchHistory()
                    }
                }
            } else {
                ContentUnavailableView(
                    "Search Your Library",
                    systemImage: "magnifyingglass",
                    description: Text("Find books, authors, series, and narrators")
                )
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Searching...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty Results

    private var emptyResults: some View {
        ContentUnavailableView.search(text: searchText)
    }

    // MARK: - Results List

    private var searchResultsList: some View {
        List {
            // Books
            if !filteredBooks.isEmpty {
                Section("Books (\(filteredBooks.count))") {
                    ForEach(filteredBooks) { book in
                        NavigationLink(value: book) {
                            BookListItem(book: book)
                        }
                    }
                }
            }

            // Authors
            if !filteredAuthors.isEmpty && (selectedCategory == .all || selectedCategory == .authors) {
                Section("Authors (\(filteredAuthors.count))") {
                    ForEach(filteredAuthors, id: \.id) { author in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)

                            Text(author.name)
                        }
                    }
                }
            }

            // Series
            if !filteredSeries.isEmpty && (selectedCategory == .all || selectedCategory == .series) {
                Section("Series (\(filteredSeries.count))") {
                    ForEach(filteredSeries, id: \.series.id) { result in
                        HStack {
                            Image(systemName: "books.vertical.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading) {
                                Text(result.series.name)
                                    .font(.headline)

                                if let count = result.books?.count {
                                    Text("\(count) books")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            // Narrators
            if !filteredNarrators.isEmpty && (selectedCategory == .all || selectedCategory == .narrators) {
                Section("Narrators (\(filteredNarrators.count))") {
                    ForEach(filteredNarrators, id: \.name) { narrator in
                        HStack {
                            Image(systemName: "mic.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)

                            Text(narrator.name)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: Book.self) { book in
            BookDetailView(book: book)
        }
    }

    // MARK: - Filtered Results

    private var filteredBooks: [Book] {
        switch selectedCategory {
        case .all, .books:
            return searchResults.books
        default:
            return []
        }
    }

    private var filteredAuthors: [SearchAuthorResult] {
        switch selectedCategory {
        case .all, .authors:
            return searchResults.authors
        default:
            return []
        }
    }

    private var filteredSeries: [SearchSeriesResult] {
        switch selectedCategory {
        case .all, .series:
            return searchResults.series
        default:
            return []
        }
    }

    private var filteredNarrators: [SearchNarratorResult] {
        switch selectedCategory {
        case .all, .narrators:
            return searchResults.narrators
        default:
            return []
        }
    }

    // MARK: - Search Logic

    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = .empty
            return
        }

        // Debounce
        isSearching = true

        Task {
            // Small delay to debounce
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            guard !Task.isCancelled, searchText == query else { return }

            do {
                guard let libraryId = appState.selectedLibrary?.id else { return }

                let response = try await APIClient.shared.searchLibrary(
                    libraryId: libraryId,
                    query: query
                )

                searchResults = SearchResults(
                    books: response.books,
                    authors: response.authors ?? [],
                    series: response.series ?? [],
                    narrators: response.narrators ?? []
                )

                // Add to history
                addToHistory(query)

            } catch {
                print("Search error: \(error)")
            }

            isSearching = false
        }
    }

    // MARK: - Search History

    private func loadSearchHistory() {
        searchHistory = UserDefaults.standard.stringArray(forKey: "searchHistory") ?? []
    }

    private func saveSearchHistory() {
        UserDefaults.standard.set(searchHistory, forKey: "searchHistory")
    }

    private func addToHistory(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Remove if already exists
        searchHistory.removeAll { $0.lowercased() == trimmed.lowercased() }

        // Add to front
        searchHistory.insert(trimmed, at: 0)

        // Keep only last 10
        if searchHistory.count > 10 {
            searchHistory = Array(searchHistory.prefix(10))
        }

        saveSearchHistory()
    }
}

// MARK: - Preview

#Preview {
    SearchView()
        .environment(AppState())
}
