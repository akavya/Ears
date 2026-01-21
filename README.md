# Ears - Native iOS App for Audiobookshelf

<p align="center">
  <img src="docs/icon.png" alt="Ears Logo" width="120" height="120">
</p>

<p align="center">
  <strong>The best-in-class native iOS audiobook app for Audiobookshelf</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#requirements">Requirements</a> •
  <a href="#building">Building</a> •
  <a href="#contributing">Contributing</a>
</p>

---

## Why Ears?

Ears solves every frustration users have with existing Audiobookshelf iOS apps:

- **Never crashes, never loses progress** - Automatic crash recovery with position persistence
- **Works everywhere** - CarPlay, AirPods, Lock Screen, Background playback
- **Accessible by default** - Full VoiceOver support, Dynamic Type
- **Premium feel** - Fluid animations, haptic feedback, attention to detail

## Features

### Core Playback
- Bulletproof audio engine that never loses your place
- Progress saved every 5 seconds, synced to server
- Proper headphone remote support (single/double/triple tap)
- Smart sleep timer with auto-restart on resume

### Library Management
- Fast alphabet scrubber for large libraries
- Dedicated Author and Narrator browsing
- Lightning-fast local search
- Beautiful cover art caching

### Smart Features
- Auto-resume last book on launch (optional)
- Auto-download next book in series
- Storage usage display with cleanup options
- Bedroom mode with OLED-black theme

### CarPlay
- Full library browsing in your car
- Now Playing with chapter navigation
- Rock-solid stability while driving

### Accessibility
- Full VoiceOver support (AudioBooth standard)
- Dynamic Type throughout
- Reduce Motion support
- High contrast mode

## Screenshots

<p align="center">
  <i>Screenshots coming soon</i>
</p>

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- An Audiobookshelf server (v2.0.0+)

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/akavya/Ears.git
   ```

2. Open the project in Xcode:
   ```bash
   cd Ears
   open Ears.xcodeproj
   ```

3. Select your development team in Signing & Capabilities

4. Build and run on your device (Simulator works but CarPlay/audio testing requires a real device)

### TestFlight

*Coming soon*

## Building

### Debug Build
```bash
xcodebuild -scheme Ears -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Release Build
```bash
xcodebuild -scheme Ears -configuration Release -destination 'generic/platform=iOS'
```

## Architecture

Ears follows a clean MVVM architecture with the Observation framework:

```
Ears/
├── App/              # App entry point, state, crash recovery
├── Features/         # Feature modules (Auth, Library, Player, etc.)
├── Core/             # Shared infrastructure (Audio, Network, Persistence)
├── DesignSystem/     # Theme, components, styling
├── Accessibility/    # VoiceOver helpers, announcements
└── Widgets/          # Home screen widgets
```

### Key Design Decisions

1. **SwiftUI + Observation** - Modern, reactive UI with clean state management
2. **SwiftData** - Native persistence ready for iCloud sync
3. **AVFoundation** - Full control over audio playback
4. **async/await** - Clean asynchronous code throughout

## API Compatibility

Ears is designed to work with Audiobookshelf server v2.0.0 and above. It uses the official REST API:

- Authentication with token refresh
- Library and item browsing
- Playback session management
- Progress synchronization
- Cover image caching

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`xcodebuild test`)
5. Commit (`git commit -m 'Add amazing feature'`)
6. Push (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Testing

### Unit Tests
```bash
xcodebuild test -scheme Ears -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Manual Testing Checklist

- [ ] Force-quit during playback → Should auto-resume exact position
- [ ] Lock phone → Audio continues, lock screen controls work
- [ ] CarPlay → Browse library, play book, chapter skip works
- [ ] AirPods → Double-tap skips chapter, play/pause reliable
- [ ] Sleep timer → Resume via headphones restarts timer
- [ ] VoiceOver → Navigate entire app, all controls labeled
- [ ] Large library (500+ books) → Smooth scrolling, alphabet scrubber works

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Audiobookshelf](https://github.com/advplyr/audiobookshelf) - The amazing self-hosted audiobook server
- [ShelfPlayer](https://github.com/rasmuslos/ShelfPlayer) - Inspiration and reference
- [BookPlayer](https://github.com/TortugaPower/BookPlayer) - Auto-sleep timer inspiration
- [AudioBooth](https://apps.apple.com/us/app/audiobooth-audiobooks-player/id1187497849) - Accessibility gold standard

---

<p align="center">
  Made with ❤️ for audiobook lovers
</p>
