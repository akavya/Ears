# Development Guide

## Getting Started

### Prerequisites
- macOS 14.0+ (Sonoma)
- Xcode 15.0+
- iOS 17.0+ device or simulator
- An Audiobookshelf server (v2.0.0+)

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/akavya/Ears.git
   cd Ears
   ```

2. **Open in Xcode**
   ```bash
   open Ears.xcodeproj
   ```

3. **Configure signing**
   - Select the Ears target
   - Go to Signing & Capabilities
   - Select your development team
   - Update the bundle identifier if needed

4. **Build and run**
   - Select your target device (real device recommended for audio testing)
   - Press ⌘R to build and run

### Testing with a Real Server

For full functionality, you need an Audiobookshelf server:

1. **Local development**: Run Audiobookshelf in Docker
   ```bash
   docker run -d \
     -p 13378:80 \
     -v /path/to/audiobooks:/audiobooks \
     -v /path/to/config:/config \
     ghcr.io/advplyr/audiobookshelf
   ```

2. **Connect the app**: Enter `http://localhost:13378` as server URL

---

## Architecture Overview

### Layer Structure

```
┌─────────────────────────────────────────────────────────┐
│                        App Layer                         │
│  EarsApp.swift, AppState.swift, CrashRecovery.swift     │
├─────────────────────────────────────────────────────────┤
│                     Features Layer                       │
│  Auth, Library, Player, Downloads, Settings              │
├─────────────────────────────────────────────────────────┤
│                       Core Layer                         │
│  Audio, Network, Persistence, CarPlay                    │
├─────────────────────────────────────────────────────────┤
│                    Design System                         │
│  Theme, Components, Accessibility                        │
└─────────────────────────────────────────────────────────┘
```

### Key Patterns

#### 1. Observation Framework
We use Swift 5.9's `@Observable` macro instead of `ObservableObject`:

```swift
@Observable
final class AppState {
    var isAuthenticated = false
    var currentUser: User?
    // Automatically triggers SwiftUI updates
}
```

**Why**: Less boilerplate, better performance, automatic `@MainActor` inference.

#### 2. Actor-based Networking
The `APIClient` is an actor for thread safety:

```swift
actor APIClient {
    static let shared = APIClient()

    func fetchBooks() async throws -> [Book] {
        // Thread-safe by design
    }
}
```

#### 3. Crash Recovery
Playback state is persisted every 5 seconds:

```swift
// In AudioPlayer
crashRecovery?.updatePosition(
    bookId: currentBook?.id ?? "",
    currentTime: currentTime,
    duration: duration,
    chapterIndex: currentChapterIndex
)
```

On launch, we check for interrupted sessions:
```swift
if let recovery = await crashRecovery.checkForInterruptedSession() {
    await audioPlayer.resumeFromRecovery(recovery)
}
```

---

## Key Components

### AudioPlayer

The central audio component wrapping AVPlayer:

```swift
let audioPlayer = AudioPlayer()

// Play a book
try await audioPlayer.play(book: book, startPosition: 0)

// Control playback
audioPlayer.togglePlayPause()
await audioPlayer.seek(to: 3600)
await audioPlayer.skipForward(seconds: 30)

// Chapter navigation
await audioPlayer.nextChapter()
await audioPlayer.previousChapter()
```

### AudioSessionManager

Handles iOS audio session configuration:

- Background playback
- Interruption handling (calls, Siri)
- Route changes (headphones plugged/unplugged)

### RemoteCommandManager

Maps hardware controls to actions:

| Control | Action |
|---------|--------|
| Single tap (AirPods) | Play/Pause |
| Double tap forward | Skip forward |
| Double tap backward | Skip backward |
| Long press | Siri |
| Lock screen scrubbing | Seek |

### SleepTimer

Features:
- Preset durations (5m to 2h)
- End of chapter option
- Fade-out effect
- **Auto-restart on resume** (like BookPlayer)

```swift
let sleepTimer = SleepTimer()

sleepTimer.start(duration: 900) // 15 minutes
sleepTimer.startEndOfChapter(chapterEndTime: 1800)
sleepTimer.extend(by: 300) // Add 5 minutes

// Auto-restart
sleepTimer.autoRestartEnabled = true
```

---

## SwiftData Models

### CachedBook
Local cache of book metadata for offline browsing:

```swift
@Model
final class CachedBook {
    @Attribute(.unique) var id: String
    var title: String
    var authorName: String
    var coverData: Data?
    var currentTime: TimeInterval
    var progressPercent: Double
}
```

### DownloadedFile
Tracks downloaded audiobooks:

```swift
@Model
final class DownloadedFile {
    var bookId: String
    var filePath: String
    var fileSize: Int64
    var chaptersJSON: Data?
}
```

---

## API Integration

### Authentication

```swift
// Login
let response = try await APIClient.shared.login(
    username: "user",
    password: "pass"
)

// Token stored in Keychain
KeychainManager.shared.setToken(response.token)
```

### Fetching Data

```swift
// Libraries
let libraries = try await APIClient.shared.fetchLibraries()

// Books with pagination
let response = try await APIClient.shared.fetchLibraryItems(
    libraryId: "lib-id",
    page: 0,
    limit: 50,
    sort: "media.metadata.title"
)

// Single book with progress
let book = try await APIClient.shared.fetchBook(id: "book-id")
```

### Progress Sync

```swift
// Update progress
try await APIClient.shared.updateProgress(
    bookId: book.id,
    currentTime: player.currentTime,
    duration: player.duration,
    isFinished: false
)
```

---

## CarPlay Integration

CarPlay uses `CPTemplateApplicationSceneDelegate`:

```swift
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        // Set up tabs: Now Playing, Library, Continue Listening
    }
}
```

**Info.plist configuration**:
```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>CPTemplateApplicationSceneSessionRoleApplication</key>
    <array>
        <dict>
            <key>UISceneConfigurationName</key>
            <string>CarPlay Configuration</string>
            <key>UISceneDelegateClassName</key>
            <string>$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate</string>
        </dict>
    </array>
</dict>
```

---

## Accessibility

### VoiceOver Labels

```swift
extension View {
    func accessibleBook(_ book: Book) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(bookAccessibilityLabel(book))
            .accessibilityHint(bookAccessibilityHint(book))
    }
}
```

### Announcements

```swift
VoiceOverAnnouncement.playbackStarted(title: "The Great Gatsby")
VoiceOverAnnouncement.chapterChanged(title: "Chapter 5", index: 4)
VoiceOverAnnouncement.sleepTimerSet(duration: "15 minutes")
```

### Reduce Motion

```swift
extension View {
    func animationIfAllowed<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        self.modifier(ReduceMotionModifier(animation: animation, value: value))
    }
}
```

---

## Testing

### Unit Tests
```bash
xcodebuild test -scheme Ears -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Manual Testing Checklist

#### Crash Recovery
- [ ] Play a book for 10+ seconds
- [ ] Force quit the app (swipe up from app switcher)
- [ ] Relaunch - should resume within 5 seconds of where you were

#### Background Playback
- [ ] Start playback
- [ ] Lock the device - audio should continue
- [ ] Lock screen controls should work
- [ ] Control Center controls should work

#### Sleep Timer
- [ ] Set a 5-minute timer
- [ ] Audio should fade out and pause at 5 minutes
- [ ] Resume via AirPods
- [ ] Timer should auto-restart (if setting enabled)

#### CarPlay (requires vehicle or adapter)
- [ ] Connect to CarPlay
- [ ] Browse library
- [ ] Start playback
- [ ] Use steering wheel controls
- [ ] Disconnect - playback should continue on phone

#### Large Library
- [ ] Test with 500+ books
- [ ] Scrolling should be smooth (60 fps)
- [ ] Alphabet scrubber should work
- [ ] Search should be instant

---

## Troubleshooting

### Build Errors

**"No such module 'AVFoundation'"**
- Ensure you're building for iOS, not macOS

**Signing errors**
- Select your development team in Signing & Capabilities
- Ensure your Apple ID is added to Xcode

### Runtime Issues

**Audio doesn't play in background**
- Check Info.plist has `audio` in `UIBackgroundModes`
- Check entitlements file exists

**CarPlay doesn't appear**
- CarPlay requires the `com.apple.developer.carplay-audio` entitlement
- Must be tested on real CarPlay (simulator doesn't support it fully)

**Progress not syncing**
- Check network connectivity
- Verify server URL is correct
- Check token hasn't expired

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

### Code Style

- Use SwiftLint (configuration in `.swiftlint.yml`)
- Follow Apple's Swift API Design Guidelines
- Document public APIs
- Write tests for new functionality

### Commit Messages

Format: `type: description`

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks
