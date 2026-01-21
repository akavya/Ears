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
struct SessionMediaMetadata: Codable, Sendable {
    let title: String?
    let subtitle: String?
    let author: String?
    let narrator: String?
    let seriesName: String?
    let genres: [String]?
    let publishedYear: String?
    let publisher: String?
    let description: String?
    let isbn: String?
    let asin: String?
    let language: String?
    let explicit: Bool?
}

/// Video track (for video content)
struct VideoTrack: Codable, Sendable {
    let index: Int?
    let contentUrl: String?
    let mimeType: String?
    let codec: String?
    let duration: TimeInterval?
}

/// Device info sent to server
struct DeviceInfo: Codable, Sendable {
    let clientVersion: String
    let manufacturer: String
    let model: String
    let sdkVersion: Int
    let deviceName: String
    let deviceId: String

    static var current: DeviceInfo {
        DeviceInfo(
            clientVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            manufacturer: "Apple",
            model: UIDevice.current.model,
            sdkVersion: Int(UIDevice.current.systemVersion.components(separatedBy: ".").first ?? "17") ?? 17,
            deviceName: UIDevice.current.name,
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        )
    }
}

// MARK: - Request Bodies

/// Request to start a playback session
struct StartSessionRequest: Encodable {
    let deviceInfo: DeviceInfo
    let supportedMimeTypes: [String]
    let forceDirectPlay: Bool = false
    let forceTranscode: Bool = false
    let mediaPlayer: String = "Ears"
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
