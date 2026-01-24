//
//  PlaybackSession.swift
//  Ears
//
//  Playback session models for Audiobookshelf API
//

import Foundation
import UIKit

/// Represents an active playback session
struct PlaybackSession: Codable, Identifiable, Sendable {
    let id: String
    let userId: String
    let libraryId: String
    let libraryItemId: String
    let episodeId: String?
    let mediaType: String
    let mediaMetadata: SessionMediaMetadata?
    let chapters: [Chapter]?
    let displayTitle: String?
    let displayAuthor: String?
    let coverPath: String?
    let duration: TimeInterval
    let playMethod: Int
    let mediaPlayer: String?
    let deviceInfo: DeviceInfo?
    let serverVersion: String?
    let date: String?
    let dayOfWeek: String?
    let timeListening: TimeInterval?
    let startTime: TimeInterval
    let currentTime: TimeInterval
    let startedAt: Date?
    let updatedAt: Date?

    // Audio stream info
    let audioTracks: [AudioTrack]?
    let videoTrack: VideoTrack?
}

/// Media metadata in session
/// Note: API returns arrays for authors/narrators/series, not single values
struct SessionMediaMetadata: Codable, Sendable {
    let title: String?
    let subtitle: String?
    let authors: [Author]?
    let narrators: [String]?
    let series: [SeriesEntry]?
    let genres: [String]?
    let publishedYear: String?
    let publishedDate: String?
    let publisher: String?
    let description: String?
    let isbn: String?
    let asin: String?
    let language: String?
    let explicit: Bool?
    let abridged: Bool?

    /// Helper to get author name string
    var authorName: String? {
        authors?.map(\.name).joined(separator: ", ")
    }

    /// Nested author in session metadata
    struct Author: Codable, Sendable {
        let id: String?
        let name: String
    }

    /// Series entry in session metadata
    struct SeriesEntry: Codable, Sendable {
        let id: String?
        let name: String?
        let sequence: String?
    }
}

/// Video track (for video content)
struct VideoTrack: Codable, Sendable {
    let index: Int?
    let contentUrl: String?
    let mimeType: String?
    let codec: String?
    let duration: TimeInterval?
}

/// Device info sent to/from server
/// Note: Server response may include different fields than what we send
struct DeviceInfo: Codable, Sendable {
    // Fields we send to the server
    let clientVersion: String?
    let manufacturer: String?
    let model: String?
    let sdkVersion: Int?
    let deviceName: String?
    let deviceId: String?

    // Additional fields the server may return
    let id: String?
    let userId: String?
    let ipAddress: String?
    let osName: String?
    let clientName: String?

    static var current: DeviceInfo {
        DeviceInfo(
            clientVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            manufacturer: "Apple",
            model: UIDevice.current.model,
            sdkVersion: Int(UIDevice.current.systemVersion.components(separatedBy: ".").first ?? "17") ?? 17,
            deviceName: UIDevice.current.name,
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
            id: nil,
            userId: nil,
            ipAddress: nil,
            osName: nil,
            clientName: nil
        )
    }
}

// MARK: - Request Bodies

/// Request to start a playback session
struct StartSessionRequest: Encodable {
    let deviceInfo: DeviceInfo
    let supportedMimeTypes: [String]
    let forceDirectPlay: Bool
    let forceTranscode: Bool
    let mediaPlayer: String

    init(
        deviceInfo: DeviceInfo,
        supportedMimeTypes: [String],
        forceDirectPlay: Bool = false,
        forceTranscode: Bool = false,
        mediaPlayer: String = "Ears"
    ) {
        self.deviceInfo = deviceInfo
        self.supportedMimeTypes = supportedMimeTypes
        self.forceDirectPlay = forceDirectPlay
        self.forceTranscode = forceTranscode
        self.mediaPlayer = mediaPlayer
    }
}

/// Request to sync session progress
struct SyncSessionRequest: Encodable {
    let currentTime: TimeInterval
    let duration: TimeInterval
    let timeListened: TimeInterval
}

/// Request to update progress
struct UpdateProgressRequest: Encodable {
    let currentTime: TimeInterval
    let duration: TimeInterval
    let progress: Double
    let isFinished: Bool
}
