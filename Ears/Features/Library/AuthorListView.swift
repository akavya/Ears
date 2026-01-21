//
//  AuthorListView.swift
//  Ears
//
//  Browse authors in the library
//

import SwiftUI

/// View for browsing all authors in the library.
///
/// Features:
/// - Grid of author photos
/// - Alphabet navigation
/// - Book count per author
/// - Navigate to author detail
struct AuthorListView: View {
    @Environment(AppState.self) private var appState

    @State private var authors: [Author] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    private var filteredAuthors: [Author] {
        if searchText.isEmpty {
            return authors
        }
        return authors.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && authors.isEmpty {
                    loadingView
                } else if authors.isEmpty {
                    emptyView
                } else {
                    authorGrid
                }
            }
            .navigationTitle("Authors")
            .searchable(text: $searchText, prompt: "Search authors")
            .task {
                await loadAuthors()
            }
            .refreshable {
                await loadAuthors()
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading authors...")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        ContentUnavailableView(
            "No Authors",
            systemImage: "person.2",
            description: Text("No authors found in your library")
        )
    }

    // MARK: - Author Grid

    private var authorGrid: some View {
        let columns = [
            GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 16)
        ]

        return ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(filteredAuthors) { author in
                    NavigationLink(value: author) {
                        AuthorGridItem(author: author)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationDestination(for: Author.self) { author in
            AuthorDetailView(author: author)
        }
    }

    // MARK: - Load Authors

    private func loadAuthors() async {
        guard let libraryId = appState.selectedLibrary?.id else { return }

        isLoading = true
        errorMessage = nil

        do {
            authors = try await APIClient.shared.fetchAuthors(libraryId: libraryId)
            authors.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Author Grid Item

struct AuthorGridItem: View {
    let author: Author

    var body: some View {
        VStack(spacing: 8) {
            // Author image
            authorImage
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .shadow(radius: 2)

            // Name
            Text(author.name)
                .font(.caption.bold())
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Book count
            Text("\(author.bookCount) books")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var authorImage: some View {
        if let serverURL = URL(string: UserDefaults.standard.string(forKey: "serverURL") ?? ""),
           let imageURL = author.imageURL(baseURL: serverURL) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    authorPlaceholder
                }
            }
        } else {
            authorPlaceholder
        }
    }

    private var authorPlaceholder: some View {
        ZStack {
            Color(.systemGray5)

            Text(author.name.prefix(1).uppercased())
                .font(.title.bold())
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Author Detail View

struct AuthorDetailView: View {
    let author: Author

    @State private var fullAuthor: Author?
    @State private var isLoading = true

    var displayAuthor: Author {
        fullAuthor ?? author
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                authorHeader

                // Description
                if let description = displayAuthor.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                // Books
                if let books = displayAuthor.libraryItems, !books.isEmpty {
                    booksSection(books)
                }
            }
        }
        .navigationTitle(author.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadFullAuthor()
        }
    }

    private var authorHeader: some View {
        VStack(spacing: 12) {
            AuthorGridItem(author: displayAuthor)
                .scaleEffect(1.5)
                .padding()

            Text("\(displayAuthor.bookCount) Audiobooks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func booksSection(_ books: [Book]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audiobooks")
                .font(.title3.bold())
                .padding(.horizontal)

            LazyVStack(spacing: 12) {
                ForEach(books) { book in
                    NavigationLink(value: book) {
                        BookListItem(book: book)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .navigationDestination(for: Book.self) { book in
            BookDetailView(book: book)
        }
    }

    private func loadFullAuthor() async {
        do {
            fullAuthor = try await APIClient.shared.fetchAuthor(id: author.id)
        } catch {
            // Use partial author data
        }
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    AuthorListView()
        .environment(AppState())
}
