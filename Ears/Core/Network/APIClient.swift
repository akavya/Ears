//
//  APIClient.swift
//  Ears
//
//  HTTP client for Audiobookshelf API
//

import Foundation

/// HTTP client for communicating with the Audiobookshelf server.
///
/// Handles:
/// - Authentication with token refresh
/// - Library and book fetching
/// - Playback session management
/// - Progress synchronization
actor APIClient {
    // MARK: - Singleton

    static let shared = APIClient()

    // MARK: - Properties

    private var baseURL: URL?
    private var authToken: String?

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // MARK: - Initialization

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true

        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        // Note: Audiobookshelf API uses camelCase, so no key conversion needed
        // Audiobookshelf API returns timestamps in milliseconds
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let milliseconds = try container.decode(Double.self)
            return Date(timeIntervalSince1970: milliseconds / 1000.0)
        }

        self.encoder = JSONEncoder()
        // Note: API expects camelCase, so no key conversion needed
    }

    // MARK: - Configuration

    /// Configure the API client with server URL
    func configure(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// Set the authentication token
    func setToken(_ token: String?) {
        self.authToken = token
    }

    // MARK: - Authentication

    /// Login to the server
    func login(username: String, password: String) async throws -> LoginResponse {
        let body = LoginRequest(username: username, password: password)

        var request = try makeRequest(path: "/login", method: "POST")
        request.setValue("true", forHTTPHeaderField: "x-return-tokens")
        request.httpBody = try encoder.encode(body)

        let response: LoginResponse = try await execute(request)

        // Store the token
        self.authToken = response.token

        return response
    }

    /// Fetch current user info
    func fetchCurrentUser() async throws -> User {
        let request = try makeRequest(path: "/api/me")
        return try await execute(request)
    }

    // MARK: - Libraries

    /// Fetch all available libraries
    func fetchLibraries() async throws -> [Library] {
        let request = try makeRequest(path: "/api/libraries")
        let response: LibrariesResponse = try await execute(request)
        return response.libraries
    }

    /// Fetch books in a library
    func fetchLibraryItems(
        libraryId: String,
        page: Int = 0,
        limit: Int = 50,
        sort: String = "media.metadata.title",
        filter: String? = nil
    ) async throws -> LibraryItemsResponse {
        var path = "/api/libraries/\(libraryId)/items?page=\(page)&limit=\(limit)&sort=\(sort)"
        if let filter = filter {
            path += "&filter=\(filter.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }

        let request = try makeRequest(path: path)
        return try await execute(request)
    }

    /// Search library
    func searchLibrary(libraryId: String, query: String) async throws -> SearchResponse {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let request = try makeRequest(path: "/api/libraries/\(libraryId)/search?q=\(encodedQuery)")
        return try await execute(request)
    }

    // MARK: - Books

    /// Fetch a single book's details
    func fetchBook(id: String) async throws -> Book {
        let request = try makeRequest(path: "/api/items/\(id)?expanded=1")
        return try await execute(request)
    }

    /// Get cover image URL for a book
    func coverURL(for bookId: String) -> URL? {
        guard let baseURL = baseURL else { return nil }
        return baseURL.appendingPathComponent("/api/items/\(bookId)/cover")
    }

    // MARK: - Playback

    /// Start a playback session
    func startPlaybackSession(bookId: String) async throws -> PlaybackSession {
        let body = StartSessionRequest(
            deviceInfo: DeviceInfo.current,
            // Include HLS for streaming (required for iOS) + common audio formats
            supportedMimeTypes: [
                "application/vnd.apple.mpegurl",  // HLS
                "audio/mpeg",
                "audio/mp4",
                "audio/x-m4a",
                "audio/aac",
                "audio/flac",
                "audio/ogg"
            ],
            forceDirectPlay: true,
            forceTranscode: false  // Use direct playback instead of HLS to avoid SSL issues
        )

        var request = try makeRequest(path: "/api/items/\(bookId)/play", method: "POST")
        request.httpBody = try encoder.encode(body)

        return try await execute(request)
    }

    /// Sync playback progress
    func syncSession(sessionId: String, currentTime: TimeInterval, duration: TimeInterval) async throws {
        let body = SyncSessionRequest(
            currentTime: currentTime,
            duration: duration,
            timeListened: 0
        )

        var request = try makeRequest(path: "/api/session/\(sessionId)/sync", method: "POST")
        request.httpBody = try encoder.encode(body)

        // This endpoint returns 200 with empty body on success
        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.syncFailed
        }
    }

    /// Update progress directly (without session)
    func updateProgress(bookId: String, currentTime: TimeInterval, duration: TimeInterval, isFinished: Bool) async throws {
        let body = UpdateProgressRequest(
            currentTime: currentTime,
            duration: duration,
            progress: duration > 0 ? currentTime / duration : 0,
            isFinished: isFinished
        )

        var request = try makeRequest(path: "/api/me/progress/\(bookId)", method: "PATCH")
        request.httpBody = try encoder.encode(body)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.progressUpdateFailed
        }
    }

    /// Mark book as finished
    func markAsFinished(bookId: String) async throws {
        try await updateProgress(bookId: bookId, currentTime: 0, duration: 0, isFinished: true)
    }

    // MARK: - Authors

    /// Fetch authors in a library
    func fetchAuthors(libraryId: String) async throws -> [Author] {
        let request = try makeRequest(path: "/api/libraries/\(libraryId)/authors")
        let response: AuthorsResponse = try await execute(request)
        return response.authors
    }

    /// Fetch single author details
    func fetchAuthor(id: String) async throws -> Author {
        let request = try makeRequest(path: "/api/authors/\(id)?include=items")
        return try await execute(request)
    }

    // MARK: - Series

    /// Fetch series in a library
    func fetchSeries(libraryId: String) async throws -> [Series] {
        let request = try makeRequest(path: "/api/libraries/\(libraryId)/series")
        let response: SeriesResponse = try await execute(request)
        return response.results
    }

    // MARK: - Private Helpers

    private func makeRequest(path: String, method: String = "GET") throws -> URLRequest {
        guard let baseURL = baseURL else {
            throw APIError.noServerConfigured
        }

        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                // Debug: Print raw response to understand the mismatch
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("⚠️ Failed to decode response. Raw JSON:")
                    print(jsonString)
                }
                print("⚠️ Decoding error details: \(error)")
                throw APIError.decodingFailed(error)
            }

        case 401:
            throw APIError.unauthorized

        case 403:
            throw APIError.forbidden

        case 404:
            throw APIError.notFound

        default:
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.serverError("HTTP \(httpResponse.statusCode)")
        }
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case noServerConfigured
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case decodingFailed(Error)
    case serverError(String)
    case syncFailed
    case progressUpdateFailed

    var errorDescription: String? {
        switch self {
        case .noServerConfigured:
            return "No server configured"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Authentication required"
        case .forbidden:
            return "Access denied"
        case .notFound:
            return "Resource not found"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .syncFailed:
            return "Failed to sync playback"
        case .progressUpdateFailed:
            return "Failed to update progress"
        }
    }
}

// MARK: - Error Response

struct ErrorResponse: Decodable {
    let error: String
}
