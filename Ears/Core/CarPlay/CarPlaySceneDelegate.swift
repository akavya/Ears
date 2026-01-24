//
//  CarPlaySceneDelegate.swift
//  Ears
//
//  CarPlay scene delegate for in-car experience
//

import CarPlay
import UIKit

/// CarPlay scene delegate that manages the in-car experience.
///
/// Features:
/// - Now Playing screen with chapter navigation
/// - Library browsing
/// - Continue Listening quick access
/// - Proper audio session handling
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    // MARK: - Properties

    var interfaceController: CPInterfaceController?
    var carplayScene: CPTemplateApplicationScene?

    /// Access to shared audio player via the main app state
    /// This is set when the main app launches
    static weak var sharedAudioPlayer: AudioPlayer?

    private var audioPlayer: AudioPlayer? {
        CarPlaySceneDelegate.sharedAudioPlayer
    }

    /// Speed presets for cycling
    private let speedPresets: [Float] = [1.0, 1.25, 1.5, 1.75, 2.0]

    // MARK: - Scene Lifecycle

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        self.carplayScene = templateApplicationScene

        // Set up the root template
        setupRootTemplate()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        self.carplayScene = nil
    }

    // MARK: - Template Setup

    private func setupRootTemplate() {
        let tabBarTemplate = CPTabBarTemplate(templates: [
            createNowPlayingTab(),
            createLibraryTab(),
            createContinueListeningTab(),
        ])

        interfaceController?.setRootTemplate(tabBarTemplate, animated: false, completion: nil)
    }

    // MARK: - Now Playing Tab

    private func createNowPlayingTab() -> CPTemplate {
        let nowPlayingTemplate = CPNowPlayingTemplate.shared
        nowPlayingTemplate.isAlbumArtistButtonEnabled = false
        nowPlayingTemplate.isUpNextButtonEnabled = true
        nowPlayingTemplate.upNextTitle = "Chapters"

        // Add custom buttons
        let speedButton = CPNowPlayingPlaybackRateButton { [weak self] _ in
            self?.cyclePlaybackSpeed()
        }

        let sleepButton = CPNowPlayingImageButton(
            image: UIImage(systemName: "moon") ?? UIImage()
        ) { [weak self] _ in
            self?.showSleepTimerOptions()
        }

        nowPlayingTemplate.updateNowPlayingButtons([speedButton, sleepButton])

        let tabItem = CPTabBarTemplate.make(
            template: nowPlayingTemplate,
            title: "Now Playing",
            systemName: "play.circle"
        )

        return tabItem
    }

    // MARK: - Library Tab

    private func createLibraryTab() -> CPTemplate {
        let listTemplate = CPListTemplate(
            title: "Library",
            sections: []
        )
        listTemplate.tabTitle = "Library"
        listTemplate.tabImage = UIImage(systemName: "books.vertical")

        // Load library items
        Task {
            await loadLibraryItems(into: listTemplate)
        }

        return listTemplate
    }

    private func loadLibraryItems(into template: CPListTemplate) async {
        // This would fetch from the app's state
        // For now, create placeholder items
        let items = [
            CPListItem(text: "Loading...", detailText: "Please wait"),
        ]

        let section = CPListSection(items: items)
        template.updateSections([section])
    }

    // MARK: - Continue Listening Tab

    private func createContinueListeningTab() -> CPTemplate {
        let listTemplate = CPListTemplate(
            title: "Continue",
            sections: []
        )
        listTemplate.tabTitle = "Continue"
        listTemplate.tabImage = UIImage(systemName: "clock.arrow.circlepath")

        // Load continue listening items
        Task {
            await loadContinueListening(into: listTemplate)
        }

        return listTemplate
    }

    private func loadContinueListening(into template: CPListTemplate) async {
        // This would fetch from the app's progress data
        let items = [
            CPListItem(text: "No recent books", detailText: "Start listening to see your books here"),
        ]

        let section = CPListSection(items: items)
        template.updateSections([section])
    }

    // MARK: - Actions

    private func cyclePlaybackSpeed() {
        guard let player = audioPlayer else { return }

        let currentSpeed = player.playbackRate

        // Find current speed index and get next
        if let currentIndex = speedPresets.firstIndex(of: currentSpeed) {
            let nextIndex = (currentIndex + 1) % speedPresets.count
            player.playbackRate = speedPresets[nextIndex]
        } else {
            // Current speed not in presets, find nearest higher or wrap to 1.0
            let nextSpeed = speedPresets.first { $0 > currentSpeed } ?? speedPresets[0]
            player.playbackRate = nextSpeed
        }
    }

    private func showSleepTimerOptions() {
        let alertTemplate = CPAlertTemplate(
            titleVariants: ["Sleep Timer"],
            actions: [
                CPAlertAction(title: "15 minutes", style: .default) { [weak self] _ in
                    self?.setSleepTimer(minutes: 15)
                },
                CPAlertAction(title: "30 minutes", style: .default) { [weak self] _ in
                    self?.setSleepTimer(minutes: 30)
                },
                CPAlertAction(title: "1 hour", style: .default) { [weak self] _ in
                    self?.setSleepTimer(minutes: 60)
                },
                CPAlertAction(title: "End of Chapter", style: .default) { [weak self] _ in
                    self?.setSleepTimerEndOfChapter()
                },
                CPAlertAction(title: "Cancel", style: .cancel) { _ in },
            ]
        )

        interfaceController?.presentTemplate(alertTemplate, animated: true, completion: nil)
    }

    private func setSleepTimer(minutes: Int) {
        guard let player = audioPlayer else {
            interfaceController?.dismissTemplate(animated: true, completion: nil)
            return
        }

        let duration = TimeInterval(minutes * 60)
        player.sleepTimer.start(duration: duration)
        interfaceController?.dismissTemplate(animated: true, completion: nil)
    }

    private func setSleepTimerEndOfChapter() {
        guard let player = audioPlayer else {
            interfaceController?.dismissTemplate(animated: true, completion: nil)
            return
        }

        player.sleepTimer.setEndOfChapter()
        interfaceController?.dismissTemplate(animated: true, completion: nil)
    }

    // MARK: - Book Selection

    private func playBook(bookId: String) {
        Task { @MainActor in
            do {
                // Fetch book details from API
                let book = try await APIClient.shared.fetchBook(id: bookId)

                // Start playback using the shared audio player
                if let player = audioPlayer {
                    try await player.play(book: book)
                }

                // Navigate to Now Playing template
                interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            } catch {
                // Show error alert
                let alert = CPAlertTemplate(
                    titleVariants: ["Unable to Play"],
                    actions: [
                        CPAlertAction(title: "OK", style: .cancel) { [weak self] _ in
                            self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
                        }
                    ]
                )
                interfaceController?.presentTemplate(alert, animated: true, completion: nil)
            }
        }
    }
}

// MARK: - CPTabBarTemplate Extension

extension CPTabBarTemplate {
    static func make(template: CPTemplate, title: String, systemName: String) -> CPTemplate {
        if let listTemplate = template as? CPListTemplate {
            listTemplate.tabTitle = title
            listTemplate.tabImage = UIImage(systemName: systemName)
        }
        return template
    }
}

// MARK: - CarPlay List Item Builder

extension CarPlaySceneDelegate {
    /// Create a list item for a book
    func makeBookListItem(
        title: String,
        author: String,
        progress: Double?,
        onSelect: @escaping () -> Void
    ) -> CPListItem {
        let item = CPListItem(
            text: title,
            detailText: author
        )

        if let progress = progress, progress > 0 {
            item.accessoryType = .none
            // Note: Progress indicator would be shown differently in CarPlay
        }

        item.handler = { _, completion in
            onSelect()
            completion()
        }

        return item
    }
}
