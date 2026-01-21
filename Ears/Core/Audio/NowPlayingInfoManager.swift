//
//  NowPlayingInfoManager.swift
//  Ears
//
//  Manages the lock screen and Control Center now playing information
//

import MediaPlayer
import UIKit

/// Manages the Now Playing info displayed on the lock screen and Control Center.
///
/// Updates:
/// - Title, author, chapter
/// - Album artwork
/// - Playback position and duration
/// - Playback rate
final class NowPlayingInfoManager {
    // MARK: - Properties

    private let infoCenter = MPNowPlayingInfoCenter.default()

    /// Cached artwork image
    private var cachedArtwork: MPMediaItemArtwork?
    private var cachedArtworkURL: URL?

    // MARK: - Public Methods

    /// Update the now playing info with current playback state
    func update(
        title: String,
        author: String?,
        artwork: UIImage?,
        duration: TimeInterval,
        currentTime: TimeInterval,
        playbackRate: Float,
        chapterTitle: String?
    ) {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyMediaType: MPMediaType.audioBook.rawValue,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: playbackRate,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
        ]

        // Author as artist
        if let author = author {
            nowPlayingInfo[MPMediaItemPropertyArtist] = author
            nowPlayingInfo[MPMediaItemPropertyAlbumArtist] = author
        }

        // Chapter as album title for nice display
        if let chapterTitle = chapterTitle {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = chapterTitle
        }

        // Artwork
        if let artwork = artwork {
            let mpArtwork = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = mpArtwork
            cachedArtwork = mpArtwork
        } else if let cached = cachedArtwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = cached
        }

        infoCenter.nowPlayingInfo = nowPlayingInfo
    }

    /// Update just the playback position (efficient for frequent updates)
    func updatePosition(currentTime: TimeInterval, playbackRate: Float) {
        guard var info = infoCenter.nowPlayingInfo else { return }

        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = playbackRate

        infoCenter.nowPlayingInfo = info
    }

    /// Load and set artwork from URL
    func loadArtwork(from url: URL) async {
        // Skip if same URL
        guard url != cachedArtworkURL else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return }

            cachedArtworkURL = url
            cachedArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }

            // Update info center if we have existing info
            if var info = infoCenter.nowPlayingInfo {
                info[MPMediaItemPropertyArtwork] = cachedArtwork
                infoCenter.nowPlayingInfo = info
            }
        } catch {
            print("Failed to load artwork: \(error)")
        }
    }

    /// Clear the now playing info
    func clear() {
        infoCenter.nowPlayingInfo = nil
        cachedArtwork = nil
        cachedArtworkURL = nil
    }
}
