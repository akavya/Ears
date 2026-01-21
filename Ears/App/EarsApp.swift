//
//  EarsApp.swift
//  Ears
//
//  Native iOS audiobook app for Audiobookshelf
//

import SwiftUI
import SwiftData

/// Main entry point for the Ears application.
///
/// This app uses the modern SwiftUI App lifecycle with:
/// - SwiftData for persistence (playback state, cache, settings)
/// - Scene-based architecture for CarPlay support
/// - Background audio capabilities
@main
struct EarsApp: App {
    // MARK: - State

    /// Global application state shared across all views
    @State private var appState = AppState()

    /// Crash recovery manager for auto-resume functionality
    @State private var crashRecovery = CrashRecovery()

    // MARK: - SwiftData Configuration

    /// SwiftData model container for persistence
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CachedBook.self,
            PlaybackStateRecord.self,
            DownloadedFile.self,
            ServerConfig.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier("group.com.ears.audiobookshelf")
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If container creation fails, try without group container
            // This allows the app to at least launch for debugging
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(crashRecovery)
                .task {
                    await initializeApp()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: - Initialization

    /// Initialize the app on first launch
    private func initializeApp() async {
        // Check for crash recovery - restore playback if interrupted
        if let recoveryState = await crashRecovery.checkForInterruptedSession() {
            appState.pendingRecovery = recoveryState
        }

        // Restore authentication state
        await appState.restoreAuthenticationState()

        // Initialize audio session for background playback
        appState.audioPlayer.configureAudioSession()
    }
}

// MARK: - Content View

/// Root content view that handles authentication state
struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(CrashRecovery.self) private var crashRecovery

    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView()
                    .onAppear {
                        handleRecoveryIfNeeded()
                    }
            } else {
                AuthenticationFlow()
            }
        }
        .animation(.easeInOut, value: appState.isAuthenticated)
    }

    private func handleRecoveryIfNeeded() {
        guard let recovery = appState.pendingRecovery else { return }

        // Auto-resume to exact position after crash
        Task {
            await appState.audioPlayer.resumeFromRecovery(recovery)
            appState.pendingRecovery = nil
        }
    }
}

// MARK: - Main Tab View

/// Primary navigation structure with tab bar
struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: Tab = .library

    enum Tab: Hashable {
        case library
        case authors
        case downloads
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
                .tag(Tab.library)

            AuthorListView()
                .tabItem {
                    Label("Authors", systemImage: "person.2")
                }
                .tag(Tab.authors)

            DownloadsView()
                .tabItem {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }
                .tag(Tab.downloads)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
        .safeAreaInset(edge: .bottom) {
            // Mini player appears above tab bar when playing
            if appState.audioPlayer.isActive {
                MiniPlayerView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Authentication Flow

/// Handles server setup and login
struct AuthenticationFlow: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            if appState.serverURL == nil {
                ServerSetupView()
            } else {
                LoginView()
            }
        }
    }
}
