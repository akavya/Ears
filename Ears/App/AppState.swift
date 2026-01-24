//
//  AppState.swift
//  Ears
//
//  Global application state using the Observation framework
//

import Foundation
import Observation
import SwiftUI

/// Global application state that manages authentication, settings, and core services.
///
/// Uses the modern Observation framework (@Observable) for automatic SwiftUI updates
/// without the boilerplate of ObservableObject/Published.
@Observable
final class AppState {
    // MARK: - Authentication State

    /// The configured server URL
    var serverURL: URL?

    /// Current authentication token (stored in Keychain)
    var authToken: String?

    /// Current user information
    var currentUser: User?

    /// Whether the user is authenticated
    var isAuthenticated: Bool {
        authToken != nil && currentUser != nil
    }

    // MARK: - Libraries

    /// Available libraries on the server
    var libraries: [Library] = []

    /// Currently selected library
    var selectedLibrary: Library?

    // MARK: - Audio Player

    /// The shared audio player instance
    let audioPlayer = AudioPlayer()

    // MARK: - Recovery

    /// Pending crash recovery state (set on launch if session was interrupted)
    var pendingRecovery: PlaybackRecoveryState?

    // MARK: - Settings

    /// User preferences
    var settings = UserSettings()

    // MARK: - UI State

    /// Whether to show the full-screen player
    var showingFullPlayer = false

    /// Current loading state for global operations
    var isLoading = false

    /// Global error message to display
    var errorMessage: String?

    // MARK: - Initialization

    init() {
        // Load server URL from UserDefaults
        if let urlString = UserDefaults.standard.string(forKey: "serverURL"),
           let url = URL(string: urlString) {
            self.serverURL = url
        }
    }

    // MARK: - Authentication Methods

    /// Restore authentication state from Keychain on app launch
    func restoreAuthenticationState() async {
        // Try to load token from Keychain
        if let token = KeychainManager.shared.getToken() {
            self.authToken = token

            // Validate token by fetching user info
            do {
                let user = try await APIClient.shared.fetchCurrentUser()
                self.currentUser = user

                // Load libraries
                let libs = try await APIClient.shared.fetchLibraries()
                self.libraries = libs
                self.selectedLibrary = libs.first
            } catch {
                // Token invalid, clear auth state
                await logout()
            }
        }
    }

    /// Authenticate with server
    func login(username: String, password: String) async throws {
        guard let serverURL = serverURL else {
            throw AuthError.noServerConfigured
        }

        isLoading = true
        defer { isLoading = false }

        // Configure API client with server URL
        await APIClient.shared.configure(baseURL: serverURL)

        // Perform login
        let response = try await APIClient.shared.login(username: username, password: password)

        // Store token securely
        KeychainManager.shared.setToken(response.token)
        self.authToken = response.token
        self.currentUser = response.user

        // Load libraries
        let libs = try await APIClient.shared.fetchLibraries()
        self.libraries = libs
        self.selectedLibrary = libs.first
    }

    /// Log out and clear all state
    func logout() async {
        // Stop any playback
        await audioPlayer.stop()

        // Clear Keychain
        KeychainManager.shared.clearToken()

        // Reset state
        authToken = nil
        currentUser = nil
        libraries = []
        selectedLibrary = nil
    }

    /// Configure server URL
    func setServerURL(_ url: URL) {
        self.serverURL = url
        UserDefaults.standard.set(url.absoluteString, forKey: "serverURL")
        Task {
            await APIClient.shared.configure(baseURL: url)
        }
    }
}

// MARK: - Supporting Types

/// Authentication errors
enum AuthError: LocalizedError {
    case noServerConfigured
    case invalidCredentials
    case networkError(Error)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .noServerConfigured:
            return "No server configured. Please set up your Audiobookshelf server first."
        case .invalidCredentials:
            return "Invalid username or password."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

/// User preferences stored in UserDefaults
@Observable
final class UserSettings {
    // Playback
    var autoPlayOnLaunch: Bool {
        didSet { UserDefaults.standard.set(autoPlayOnLaunch, forKey: "autoPlayOnLaunch") }
    }
    var defaultPlaybackSpeed: Float {
        didSet { UserDefaults.standard.set(defaultPlaybackSpeed, forKey: "defaultPlaybackSpeed") }
    }
    var skipForwardInterval: Int {
        didSet { UserDefaults.standard.set(skipForwardInterval, forKey: "skipForwardInterval") }
    }
    var skipBackwardInterval: Int {
        didSet { UserDefaults.standard.set(skipBackwardInterval, forKey: "skipBackwardInterval") }
    }

    // Sleep Timer
    var sleepTimerAutoRestart: Bool {
        didSet { UserDefaults.standard.set(sleepTimerAutoRestart, forKey: "sleepTimerAutoRestart") }
    }
    var lastSleepTimerDuration: TimeInterval {
        didSet { UserDefaults.standard.set(lastSleepTimerDuration, forKey: "lastSleepTimerDuration") }
    }

    // Appearance
    var bedroomModeEnabled: Bool {
        didSet { UserDefaults.standard.set(bedroomModeEnabled, forKey: "bedroomModeEnabled") }
    }
    var autoEnableBedroomMode: Bool {
        didSet { UserDefaults.standard.set(autoEnableBedroomMode, forKey: "autoEnableBedroomMode") }
    }

    // Downloads
    var autoDownloadNextInSeries: Bool {
        didSet { UserDefaults.standard.set(autoDownloadNextInSeries, forKey: "autoDownloadNextInSeries") }
    }
    var autoDeleteCompleted: Bool {
        didSet { UserDefaults.standard.set(autoDeleteCompleted, forKey: "autoDeleteCompleted") }
    }

    // Accessibility
    var hapticFeedbackEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticFeedbackEnabled, forKey: "hapticFeedbackEnabled") }
    }

    init() {
        let defaults = UserDefaults.standard

        // Load with defaults
        self.autoPlayOnLaunch = defaults.bool(forKey: "autoPlayOnLaunch")
        self.defaultPlaybackSpeed = defaults.float(forKey: "defaultPlaybackSpeed").nonZeroOr(1.0)
        self.skipForwardInterval = defaults.integer(forKey: "skipForwardInterval").nonZeroOr(30)
        self.skipBackwardInterval = defaults.integer(forKey: "skipBackwardInterval").nonZeroOr(15)

        self.sleepTimerAutoRestart = defaults.bool(forKey: "sleepTimerAutoRestart")
        self.lastSleepTimerDuration = defaults.double(forKey: "lastSleepTimerDuration").nonZeroOr(900) // 15 min default

        self.bedroomModeEnabled = defaults.bool(forKey: "bedroomModeEnabled")
        self.autoEnableBedroomMode = defaults.bool(forKey: "autoEnableBedroomMode")

        self.autoDownloadNextInSeries = defaults.bool(forKey: "autoDownloadNextInSeries")
        self.autoDeleteCompleted = defaults.bool(forKey: "autoDeleteCompleted")

        self.hapticFeedbackEnabled = defaults.object(forKey: "hapticFeedbackEnabled") == nil ? true : defaults.bool(forKey: "hapticFeedbackEnabled")
    }
}

// MARK: - Helpers

extension Float {
    func nonZeroOr(_ defaultValue: Float) -> Float {
        self == 0 ? defaultValue : self
    }
}

extension Int {
    func nonZeroOr(_ defaultValue: Int) -> Int {
        self == 0 ? defaultValue : self
    }
}

extension Double {
    func nonZeroOr(_ defaultValue: Double) -> Double {
        self == 0 ? defaultValue : self
    }
}
