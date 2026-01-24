//
//  User.swift
//  Ears
//
//  User model from Audiobookshelf API
//

import Foundation

/// Represents an Audiobookshelf user
struct User: Codable, Identifiable, Sendable {
    let id: String
    let username: String
    let type: String?
    let token: String?
    let email: String?
    let isActive: Bool?
    let isLocked: Bool?
    let lastSeen: Date?
    let createdAt: Date?
    let permissions: UserPermissions?
    let librariesAccessible: [String]?
    let itemTagsSelected: [String]?
    let mediaProgress: [MediaProgress]?
    let bookmarks: [Bookmark]?
    let seriesHideFromContinueListening: [String]?
    let hasOpenIDLink: Bool?
    let accessToken: String?
    let refreshToken: String?

    /// Whether this is a root/admin user
    var isAdmin: Bool {
        type == "root" || type == "admin"
    }

    /// Safe accessor for isActive with default
    var isUserActive: Bool {
        isActive ?? true
    }

    /// Safe accessor for isLocked with default
    var isUserLocked: Bool {
        isLocked ?? false
    }
}

/// Bookmark for an audiobook
struct Bookmark: Codable, Sendable {
    let libraryItemId: String
    let time: Double
    let title: String
    let createdAt: Date?
}

/// User permissions
struct UserPermissions: Codable, Sendable {
    let download: Bool?
    let update: Bool?
    let delete: Bool?
    let upload: Bool?
    let accessAllLibraries: Bool?
    let accessAllTags: Bool?
    let accessExplicitContent: Bool?
    let createEreader: Bool?
    let selectedTagsNotAccessible: Bool?
}

// MARK: - Login

/// Login request body
struct LoginRequest: Encodable {
    let username: String
    let password: String
}

/// Login response
struct LoginResponse: Decodable {
    let user: User
    let userDefaultLibraryId: String?
    let serverSettings: ServerSettings?
    let token: String

    private enum CodingKeys: String, CodingKey {
        case user
        case userDefaultLibraryId
        case serverSettings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user = try container.decode(User.self, forKey: .user)
        userDefaultLibraryId = try container.decodeIfPresent(String.self, forKey: .userDefaultLibraryId)
        serverSettings = try container.decodeIfPresent(ServerSettings.self, forKey: .serverSettings)

        // Token comes from user object
        token = user.token ?? ""
    }
}

/// Server settings
struct ServerSettings: Codable, Sendable {
    let id: String?
    let scannerFindCovers: Bool?
    let scannerCoverProvider: String?
    let scannerParseSubtitle: Bool?
    let scannerPreferMatchedMetadata: Bool?
    let storeCoverWithItem: Bool?
    let storeMetadataWithItem: Bool?
    let metadataFileFormat: String?
    let rateLimitLoginRequests: Int?
    let rateLimitLoginWindow: Int?
    let backupsToKeep: Int?
    let maxBackupSize: Int?
    let loggerDailyLogsToKeep: Int?
    let loggerScannerLogsToKeep: Int?
    let homeBookshelfView: Int?
    let bookshelfView: Int?
    let sortingIgnorePrefix: Bool?
    let sortingPrefixes: [String]?
    let chromecastEnabled: Bool?
    let dateFormat: String?
    let language: String?
    let logLevel: Int?
    let version: String?
}
