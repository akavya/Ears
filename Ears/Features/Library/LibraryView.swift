//
//  LibraryView.swift
//  Ears
//
//  Main library browsing view with alphabet scrubber
//

import SwiftUI

/// Main library view showing all audiobooks with alphabet navigation.
///
/// Features:
/// - Grid/List view toggle
/// - Alphabet scrubber for quick navigation (like Contacts app)
/// - Pull to refresh
/// - Continue Listening section
/// - Search integration
struct LibraryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = LibraryViewModel()
    @State private var showSearch = false
    @State private var isGridView = true
    @State private var selectedSortOption: SortOption = .title
    @State private var showSortOptions = false

    enum SortOption: String, CaseIterable {
        case title = "Title"
        case author = "Author"
        case recentlyAdded = "Recently Added"
        case recentlyPlayed = "Recently Played"

        var apiValue: String {
            switch self {
            case .title: return "media.metadata.title"
            case .author: return "media.metadata.authorName"
            case .recentlyAdded: return "addedAt"
            case .recentlyPlayed: return "progress.lastUpdate"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.books.isEmpty {
                    loadingView
                } else if viewModel.books.isEmpty {
                    emptyView
                } else {
                    libraryContent
                }

                // Alphabet scrubber
                if !viewModel.books.isEmpty && isGridView {
                    AlphabetScrubber(
                        letters: viewModel.availableLetters,
                        onSelect: { letter in
                            scrollToLetter(letter)
                        }
                    )
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    libraryPicker
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }

                    Menu {
                        Picker("Sort by", selection: $selectedSortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }

                        Divider()

                        Button {
                            isGridView.toggle()
                        } label: {
                            Label(
                                isGridView ? "List View" : "Grid View",
                                systemImage: isGridView ? "list.bullet" : "square.grid.2x2"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showSearch) {
                SearchView()
            }
            .task {
                await loadLibrary()
            }
            .onChange(of: selectedSortOption) { _, newValue in
                Task {
                    await viewModel.loadBooks(sort: newValue.apiValue)
                }
            }
            .onChange(of: appState.selectedLibrary) { _, _ in
                Task {
                    await loadLibrary()
                }
            }
        }
    }

    // MARK: - Library Picker

    private var libraryPicker: some View {
        Menu {
            ForEach(appState.libraries.filter(\.isAudiobookLibrary)) { library in
                Button {
                    appState.selectedLibrary = library
                } label: {
                    HStack {
                        Text(library.name)
                        if library.id == appState.selectedLibrary?.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(appState.selectedLibrary?.name ?? "Library")
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption.bold())
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading library...")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        ContentUnavailableView(
            "No Audiobooks",
            systemImage: "books.vertical",
            description: Text("Your library is empty. Add some audiobooks to your Audiobookshelf server.")
        )
    }

    // MARK: - Library Content

    @State private var scrollPosition: String?

    private var libraryContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24, pinnedViews: .sectionHeaders) {
                // Continue Listening section
                if !viewModel.continueListening.isEmpty {
                    continueListeningSection
                }

                // Main library grid
                if isGridView {
                    bookGrid
                } else {
                    bookList
                }
            }
            .padding(.horizontal)
        }
        .scrollPosition(id: $scrollPosition)
    }

    // MARK: - Continue Listening

    private var continueListeningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue Listening")
                .font(.title2.bold())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.continueListening) { book in
                        NavigationLink(value: book) {
                            ContinueListeningCard(book: book)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top)
    }

    // MARK: - Book Grid

    private var bookGrid: some View {
        let columns = [
            GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 16)
        ]

        return LazyVGrid(columns: columns, spacing: 20) {
            ForEach(viewModel.books) { book in
                NavigationLink(value: book) {
                    BookGridItem(book: book)
                }
                .buttonStyle(.plain)
                .id(book.id)
            }

            // Load more trigger
            if viewModel.hasMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .task {
                        await viewModel.loadMore()
                    }
            }
        }
        .padding(.vertical)
        .navigationDestination(for: Book.self) { book in
            BookDetailView(book: book)
        }
    }

    // MARK: - Book List

    private var bookList: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.books) { book in
                NavigationLink(value: book) {
                    BookListItem(book: book)
                }
                .buttonStyle(.plain)
                .id(book.id)
            }

            if viewModel.hasMore {
                ProgressView()
                    .task {
                        await viewModel.loadMore()
                    }
            }
        }
        .padding(.vertical)
        .navigationDestination(for: Book.self) { book in
            BookDetailView(book: book)
        }
    }

    // MARK: - Actions

    private func loadLibrary() async {
        guard let library = appState.selectedLibrary else { return }
        await viewModel.setLibrary(library)
        await viewModel.loadBooks(sort: selectedSortOption.apiValue)
    }

    private func scrollToLetter(_ letter: String) {
        // Find first book starting with this letter
        if let book = viewModel.books.first(where: { $0.title.prefix(1).uppercased() == letter }) {
            withAnimation {
                scrollPosition = book.id
            }
        }
    }
}

// MARK: - Alphabet Scrubber

struct AlphabetScrubber: View {
    let letters: [String]
    let onSelect: (String) -> Void

    @State private var selectedLetter: String?
    @State private var isDragging = false

    var body: some View {
        HStack {
            Spacer()

            VStack(spacing: 2) {
                ForEach(letters, id: \.self) { letter in
                    Text(letter)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(selectedLetter == letter ? .accentColor : .secondary)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
            .background(.ultraThinMaterial, in: Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        selectLetter(at: value.location.y)
                    }
                    .onEnded { _ in
                        isDragging = false
                        selectedLetter = nil
                    }
            )
        }
        .padding(.trailing, 4)
        .overlay {
            if isDragging, let letter = selectedLetter {
                // Large letter indicator
                Text(letter)
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 80, height: 80)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func selectLetter(at y: CGFloat) {
        let letterHeight: CGFloat = 16
        let padding: CGFloat = 4
        let index = Int((y - padding) / letterHeight)

        if index >= 0 && index < letters.count {
            let letter = letters[index]
            if letter != selectedLetter {
                selectedLetter = letter
                onSelect(letter)

                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LibraryView()
        .environment(AppState())
}
