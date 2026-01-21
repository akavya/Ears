//
//  AudioPlayer.swift
//  Ears
//
//  Robust AVPlayer wrapper with crash recovery and proper error handling
//

import AVFoundation
import Observation
import MediaPlayer

/// A robust audio player built on AVPlayer with:
/// - Automatic error recovery
/// - Background playback support
/// - Crash recovery integration
/// - Remote command support
/// - Sleep timer integration
@Observable
final class AudioPlayer {
    // MARK: - Playback State

    enum PlaybackState: Equatable {
        case idle
        case loading
        case playing
        case paused
        case error(String)

        var isPlaying: Bool {
            self == .playing
        }
    }

    // MARK: - Published Properties

    /// Current playback state
    private(set) var state: PlaybackState = .idle

    /// Currently loaded book
    private(set) var currentBook: Book?

    /// Current playback position in seconds
    private(set) var currentTime: TimeInterval = 0

    /// Total duration in seconds
    private(set) var duration: TimeInterval = 0

    /// Current chapter (if available)
    private(set) var currentChapter: Chapter?

    /// Current chapter index
    private(set) var currentChapterIndex: Int = 0

    /// Playback rate (speed)
    var playbackRate: Float = 1.0 {
        didSet {
            player?.rate = state.isPlaying ? playbackRate : 0
            UserDefaults.standard.set(playbackRate, forKey: "lastPlaybackRate")
        }
    }

    /// Whether any content is loaded
    var isActive: Bool {
        currentBook != nil && state != .idle
    }

    // MARK: - Private Properties

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var itemEndObserver: NSObjectProtocol?

    /// Audio session manager
    private let audioSession = AudioSessionManager()

    /// Sleep timer
    let sleepTimer = SleepTimer()

    /// Now playing info manager
    private let nowPlayingManager = NowPlayingInfoManager()

    /// Remote command manager
    private let remoteCommands = RemoteCommandManager()

    /// Crash recovery reference (set by app)
    weak var crashRecovery: CrashRecovery?

    // MARK: - Initialization

    init() {
        // Load last playback rate
        let savedRate = UserDefaults.standard.float(forKey: "lastPlaybackRate")
        if savedRate > 0 {
            playbackRate = savedRate
        }

        // Set up remote command callbacks
        setupRemoteCommands()

        // Set up sleep timer callback
        sleepTimer.onTimerFired = { [weak self] in
            self?.handleSleepTimerFired()
        }
    }

    deinit {
        cleanup()
    }

    // MARK: - Audio Session Configuration

    /// Configure audio session for background playback
    func configureAudioSession() {
        audioSession.configure()
    }

    // MARK: - Playback Control

    /// Load and play a book from a URL
    @MainActor
    func play(book: Book, startPosition: TimeInterval = 0) async throws {
        guard let audioURL = book.audioFileURL else {
            throw AudioPlayerError.invalidURL
        }

        state = .loading
        currentBook = book

        // Clean up previous playback
        cleanup()

        // Configure audio session
        try audioSession.activate()

        // Create player item
        let asset = AVURLAsset(url: audioURL)
        playerItem = AVPlayerItem(asset: asset)

        // Create player
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true

        // Set up observers
        setupObservers()

        // Wait for item to be ready
        try await waitForPlayerReady()

        // Get duration
        if let duration = playerItem?.duration, duration.isNumeric {
            self.duration = duration.seconds
        }

        // Seek to start position
        if startPosition > 0 {
            await seek(to: startPosition)
        }

        // Start playback
        player?.rate = playbackRate
        state = .playing

        // Update now playing info
        updateNowPlayingInfo()

        // Start crash recovery tracking
        crashRecovery?.startTracking(
            bookId: book.id,
            currentTime: currentTime,
            duration: duration,
            chapterIndex: currentChapterIndex
        )

        // Update chapter info
        updateCurrentChapter()
    }

    /// Resume playback
    @MainActor
    func resume() {
        guard state == .paused, let player = player else { return }

        do {
            try audioSession.activate()
            player.rate = playbackRate
            state = .playing
            updateNowPlayingInfo()
            crashRecovery?.resumeTracking(bookId: currentBook?.id ?? "")
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Pause playback
    @MainActor
    func pause() {
        guard state.isPlaying, let player = player else { return }

        player.pause()
        state = .paused
        updateNowPlayingInfo()

        // Sync progress to server
        syncProgress()

        crashRecovery?.pauseTracking()
    }

    /// Toggle play/pause
    @MainActor
    func togglePlayPause() {
        if state.isPlaying {
            pause()
        } else if state == .paused {
            resume()
        }
    }

    /// Stop playback and reset
    @MainActor
    func stop() {
        // Sync final progress
        syncProgress()

        cleanup()
        state = .idle
        currentBook = nil
        currentTime = 0
        duration = 0
        currentChapter = nil

        crashRecovery?.stopTracking()
        nowPlayingManager.clear()
    }

    /// Seek to a specific position
    @MainActor
    func seek(to time: TimeInterval) async {
        guard let player = player else { return }

        let cmTime = CMTime(seconds: time, preferredTimescale: 1000)

        // Use accurate seeking to prevent iOS bugs with seeking
        await player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)

        currentTime = time
        updateNowPlayingInfo()
        updateCurrentChapter()

        // Update crash recovery
        crashRecovery?.updatePosition(
            bookId: currentBook?.id ?? "",
            currentTime: currentTime,
            duration: duration,
            chapterIndex: currentChapterIndex
        )
    }

    /// Skip forward by interval
    @MainActor
    func skipForward(seconds: TimeInterval = 30) async {
        let newTime = min(currentTime + seconds, duration)
        await seek(to: newTime)
    }

    /// Skip backward by interval
    @MainActor
    func skipBackward(seconds: TimeInterval = 15) async {
        let newTime = max(currentTime - seconds, 0)
        await seek(to: newTime)
    }

    /// Jump to next chapter
    @MainActor
    func nextChapter() async {
        guard let book = currentBook,
              currentChapterIndex < book.chapters.count - 1 else { return }

        let nextChapter = book.chapters[currentChapterIndex + 1]
        await seek(to: nextChapter.startTime)
    }

    /// Jump to previous chapter
    @MainActor
    func previousChapter() async {
        guard let book = currentBook else { return }

        // If more than 3 seconds into chapter, go to start of current chapter
        if let currentChapter = currentChapter,
           currentTime - currentChapter.startTime > 3 {
            await seek(to: currentChapter.startTime)
            return
        }

        // Otherwise go to previous chapter
        guard currentChapterIndex > 0 else { return }
        let prevChapter = book.chapters[currentChapterIndex - 1]
        await seek(to: prevChapter.startTime)
    }

    /// Jump to specific chapter
    @MainActor
    func jumpToChapter(_ index: Int) async {
        guard let book = currentBook,
              index >= 0 && index < book.chapters.count else { return }

        let chapter = book.chapters[index]
        await seek(to: chapter.startTime)
    }

    /// Resume from crash recovery state
    @MainActor
    func resumeFromRecovery(_ state: PlaybackRecoveryState) async {
        // Fetch book details and resume playback
        do {
            let book = try await APIClient.shared.fetchBook(id: state.bookId)
            try await play(book: book, startPosition: state.currentTime)
        } catch {
            // Recovery failed, clear state
            self.state = .error("Failed to resume: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }

        statusObserver?.invalidate()
        statusObserver = nil

        if let observer = itemEndObserver {
            NotificationCenter.default.removeObserver(observer)
            itemEndObserver = nil
        }

        player?.pause()
        player = nil
        playerItem = nil
    }

    private func setupObservers() {
        guard let player = player, let item = playerItem else { return }

        // Time observer - update current time frequently
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.handleTimeUpdate(time)
        }

        // Status observer
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                self?.handleStatusChange(item.status)
            }
        }

        // End of item observer
        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePlaybackEnded()
            }
        }
    }

    private func handleTimeUpdate(_ time: CMTime) {
        guard time.isNumeric else { return }

        currentTime = time.seconds
        updateCurrentChapter()

        // Update crash recovery periodically
        crashRecovery?.updatePosition(
            bookId: currentBook?.id ?? "",
            currentTime: currentTime,
            duration: duration,
            chapterIndex: currentChapterIndex
        )

        // Update sleep timer
        sleepTimer.tick()
    }

    @MainActor
    private func handleStatusChange(_ status: AVPlayerItem.Status) {
        switch status {
        case .failed:
            if let error = playerItem?.error {
                state = .error(error.localizedDescription)
            } else {
                state = .error("Unknown playback error")
            }
        case .readyToPlay:
            // Status is now ready
            break
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    @MainActor
    private func handlePlaybackEnded() {
        state = .paused
        syncProgress()

        // Mark book as finished
        Task {
            try? await APIClient.shared.markAsFinished(bookId: currentBook?.id ?? "")
        }
    }

    private func waitForPlayerReady() async throws {
        guard let item = playerItem else {
            throw AudioPlayerError.notLoaded
        }

        // Wait for the item to be ready
        for await status in item.publisher(for: \.status).values {
            switch status {
            case .readyToPlay:
                return
            case .failed:
                throw item.error ?? AudioPlayerError.loadFailed
            case .unknown:
                continue
            @unknown default:
                continue
            }
        }
    }

    private func updateCurrentChapter() {
        guard let book = currentBook else { return }

        // Find the chapter containing current time
        for (index, chapter) in book.chapters.enumerated() {
            let endTime = index < book.chapters.count - 1
                ? book.chapters[index + 1].startTime
                : duration

            if currentTime >= chapter.startTime && currentTime < endTime {
                if currentChapterIndex != index {
                    currentChapterIndex = index
                    currentChapter = chapter
                }
                return
            }
        }
    }

    private func updateNowPlayingInfo() {
        guard let book = currentBook else { return }

        nowPlayingManager.update(
            title: book.title,
            author: book.authorName,
            artwork: nil, // TODO: Load artwork
            duration: duration,
            currentTime: currentTime,
            playbackRate: state.isPlaying ? playbackRate : 0,
            chapterTitle: currentChapter?.title
        )
    }

    private func syncProgress() {
        guard let book = currentBook else { return }

        Task {
            try? await APIClient.shared.updateProgress(
                bookId: book.id,
                currentTime: currentTime,
                duration: duration,
                isFinished: currentTime >= duration - 10
            )
        }
    }

    // MARK: - Remote Commands

    private func setupRemoteCommands() {
        remoteCommands.onPlay = { [weak self] in
            Task { @MainActor in
                self?.resume()
            }
            return .success
        }

        remoteCommands.onPause = { [weak self] in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }

        remoteCommands.onTogglePlayPause = { [weak self] in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }

        remoteCommands.onSkipForward = { [weak self] interval in
            Task { @MainActor in
                await self?.skipForward(seconds: interval)
            }
            return .success
        }

        remoteCommands.onSkipBackward = { [weak self] interval in
            Task { @MainActor in
                await self?.skipBackward(seconds: interval)
            }
            return .success
        }

        remoteCommands.onSeek = { [weak self] position in
            Task { @MainActor in
                await self?.seek(to: position)
            }
            return .success
        }

        remoteCommands.onNextTrack = { [weak self] in
            Task { @MainActor in
                await self?.nextChapter()
            }
            return .success
        }

        remoteCommands.onPreviousTrack = { [weak self] in
            Task { @MainActor in
                await self?.previousChapter()
            }
            return .success
        }

        remoteCommands.register()
    }

    // MARK: - Sleep Timer

    private func handleSleepTimerFired() {
        Task { @MainActor in
            // Save progress before sleeping
            syncProgress()

            // Fade out and pause
            await fadeOutAndPause()
        }
    }

    private func fadeOutAndPause() async {
        guard let player = player else { return }

        // Fade out over 3 seconds
        let steps = 30
        let interval: TimeInterval = 3.0 / Double(steps)
        let volumeStep = player.volume / Float(steps)

        for _ in 0..<steps {
            player.volume -= volumeStep
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }

        pause()
        player.volume = 1.0 // Reset for next play
    }
}

// MARK: - Errors

enum AudioPlayerError: LocalizedError {
    case invalidURL
    case notLoaded
    case loadFailed
    case playbackFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid audio URL"
        case .notLoaded:
            return "No audio loaded"
        case .loadFailed:
            return "Failed to load audio"
        case .playbackFailed:
            return "Playback failed"
        }
    }
}
