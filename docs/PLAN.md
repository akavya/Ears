# Ears - Native iOS App for Audiobookshelf

## Vision
Build **Ears** - the best-in-class native iOS audiobook app for Audiobookshelf. One that solves every frustration users have with existing apps while delivering a premium, polished experience.

---

## Research: Pain Points of Existing Apps

### 🔴 Critical Bugs (Must Solve)

| Issue | Source | Our Solution |
|-------|--------|--------------|
| **Crashes during playback** - Random, no pattern | [Discussion #864](https://github.com/advplyr/audiobookshelf-app/discussions/864) | Robust error handling, crash recovery with auto-resume |
| **Crashes when app loses focus** - Major problem while driving | Same | Background audio properly isolated from UI thread |
| **Progress lost after crash** - Returns to main menu | Same | Persist playback state every 5 seconds, auto-resume to exact position |
| **Seeking resets playback to 0** - Cross-app iOS bug | [Issue #4763](https://github.com/advplyr/audiobookshelf/issues/4763) | Investigate AVPlayer seeking implementation |
| **Sleep timer resets progress** | [ShelfPlayer #422](https://github.com/rasmuslos/ShelfPlayer/issues/422) | Save progress before sleep timer activates |
| **CarPlay not working/crashing** | [ShelfPlayer #408](https://github.com/rasmuslos/ShelfPlayer/issues/408) | Dedicated CarPlay testing, proper audio session handling |
| **Downloads stall** with large libraries | [Issue #1253](https://github.com/advplyr/audiobookshelf-app/issues/1253) | Background download queue with resume capability |

### 🟠 Navigation & UX Frustrations

| Issue | Source | Our Solution |
|-------|--------|--------------|
| **No auto-resume** to last book on launch | [Issue #4566](https://github.com/advplyr/audiobookshelf/issues/4566) | Settings toggle: "Auto-play last book on launch" |
| **Slow startup even offline** | Discussion #864 | Lazy loading, immediate UI with cached data |
| **Search runs forever** for non-author queries | ShelfPlayer reviews | Local search with proper indexing |
| **Genre filtering returns no results** | ShelfPlayer reviews | Fix filter logic, clear error states |
| **No alphabet index** for large libraries | [Discussion #527](https://github.com/advplyr/audiobookshelf-app/discussions/527) | Side alphabet scrubber like Contacts app |
| **Only 5-10 items** in home sections | Same | Configurable limits, "See All" navigation |
| **Missing narrator info** everywhere | Same | Narrator on cards, player, detail views |
| **No dedicated Author/Narrator tabs** | Same | Full Author and Narrator browse screens |
| **Mini player can't be dismissed** | SoundLeaf FAQ | Swipe down to dismiss, or tap to expand |
| **Bright screen on wake** - Disturbs dark rooms | Discussion #864 | "Bedtime mode" with dimmed UI, OLED black |

### 🟡 Audio & Playback Issues

| Issue | Source | Our Solution |
|-------|--------|--------------|
| **Headphone remote unreliable** | Discussion #864 | Proper `MPRemoteCommandCenter` implementation |
| **No next/previous chapter** via remote | Same | Map double/triple tap to chapter skip |
| **Queue not working** for podcasts | Same | Proper queue management with series/playlist support |
| **Sleep timer doesn't restart** when resuming via headphones | [ShelfPlayer #394](https://github.com/rasmuslos/ShelfPlayer/issues/394) | Auto-restart sleep timer option (like BookPlayer) |
| **Podcast episodes repeat** after last | [ShelfPlayer #400](https://github.com/rasmuslos/ShelfPlayer/issues/400) | Proper end-of-queue handling |

### 🟢 Missing Features Users Want

| Feature | Source | Priority |
|---------|--------|----------|
| **Auto-sleep timer restart** | [BookPlayer inspiration](https://apps.apple.com/us/app/bookplayer/id1138219998) | High - beloved feature |
| **Playback history with timestamps** | [ShelfPlayer #399](https://github.com/rasmuslos/ShelfPlayer/issues/399) | Medium |
| **Auto-download next book** in series | Discussion #864 | High |
| **Auto-delete completed books** | Same | Medium |
| **Storage usage display** | Common request | High |
| **Haptic feedback toggle** | [ShelfPlayer #393](https://github.com/rasmuslos/ShelfPlayer/issues/393) | Medium |
| **EPUB3 read-along** (audio sync) | Discussion #527 | Low (complex) |

### ♿ Accessibility (Critical for Premium)

| Issue | Source | Our Solution |
|-------|--------|--------------|
| **VoiceOver not properly supported** | [AppleVis reviews](https://www.applevis.com/apps/ios/books/audiobooth-audiobooks-player) | Follow AudioBooth's gold-standard accessibility |
| **Missing control labels** | Same | Proper `accessibilityLabel` on all controls |
| **Focus order issues** | Same | Logical `accessibilityElement` ordering |
| **No auto-resume accessibility option** | Issue #4566 | Settings accessible to all users |

---

## Design Principles

### Inspired By The Best

| App | What to Learn |
|-----|---------------|
| **Apple Books** | Clean, intuitive design, native feel |
| **Audible** | Complete feature set, excellent accessibility |
| **BookPlayer** | Auto-sleep restart, best CarPlay experience |
| **Still** | Minimalist philosophy - add only what matters |
| **AudioBooth** | VoiceOver gold standard |

### Core Philosophy

1. **Stability First** - Never crash, never lose progress
2. **Instant Resume** - Pick up exactly where you left off, always
3. **Works Everywhere** - CarPlay, AirPods, Lock Screen, Background
4. **Accessible by Default** - VoiceOver, Dynamic Type from day one
5. **Thoughtful Defaults** - Smart behaviors that just work
6. **Premium Feel** - Fluid animations, haptic feedback, attention to detail

---

## Technology Stack

| Component | Technology | Why |
|-----------|------------|-----|
| **UI** | SwiftUI | Modern, declarative, Apple's future |
| **Architecture** | MVVM + Observation | Clean, testable, reactive |
| **Networking** | async/await + URLSession | Native, efficient |
| **Audio** | AVFoundation + AVAudioSession | Full playback control |
| **Background** | BGTaskScheduler | Reliable background processing |
| **Storage** | SwiftData | Modern persistence, iCloud ready |
| **Keychain** | KeychainAccess | Secure token storage |

---

## App Architecture

```
Ears/
├── App/
│   ├── EarsApp.swift
│   ├── AppState.swift              # Global app state
│   └── CrashRecovery.swift         # Auto-resume after crash
│
├── Features/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   ├── ServerSetupView.swift
│   │   └── AuthViewModel.swift
│   │
│   ├── Library/
│   │   ├── LibraryView.swift       # With alphabet scrubber
│   │   ├── BookGridView.swift
│   │   ├── BookDetailView.swift
│   │   ├── AuthorView.swift        # Dedicated author browse
│   │   ├── NarratorView.swift      # Dedicated narrator browse
│   │   ├── SearchView.swift        # Fast local search
│   │   └── LibraryViewModel.swift
│   │
│   ├── Player/
│   │   ├── NowPlayingView.swift    # Full immersive player
│   │   ├── MiniPlayerView.swift    # Dismissible, expandable
│   │   ├── ChapterListView.swift
│   │   ├── SleepTimerView.swift    # With auto-restart option
│   │   ├── SpeedControlView.swift
│   │   └── PlayerViewModel.swift
│   │
│   ├── Downloads/
│   │   ├── DownloadsView.swift
│   │   ├── StorageView.swift       # Storage usage
│   │   └── DownloadManager.swift   # Background downloads
│   │
│   └── Settings/
│       ├── SettingsView.swift
│       ├── AppearanceSettings.swift
│       ├── PlaybackSettings.swift  # Auto-resume, skip intervals
│       ├── AccessibilitySettings.swift
│       └── BedroomModeSettings.swift
│
├── Core/
│   ├── Audio/
│   │   ├── AudioPlayer.swift       # Robust AVPlayer wrapper
│   │   ├── AudioSession.swift      # Session management
│   │   ├── NowPlayingInfo.swift    # Lock screen controls
│   │   ├── RemoteCommands.swift    # Headphone controls
│   │   └── SleepTimer.swift        # With fade & auto-restart
│   │
│   ├── Network/
│   │   ├── APIClient.swift
│   │   ├── WebSocketClient.swift
│   │   └── Models/
│   │
│   ├── Persistence/
│   │   ├── PlaybackState.swift     # Persisted every 5 sec
│   │   ├── CacheManager.swift
│   │   └── OfflineStorage.swift
│   │
│   └── CarPlay/
│       └── CarPlaySceneDelegate.swift
│
├── DesignSystem/
│   ├── Theme.swift
│   ├── BedroomMode.swift           # Dimmed dark theme
│   └── Components/
│
├── Accessibility/
│   ├── AccessibilityHelpers.swift
│   └── VoiceOverAnnouncements.swift
│
└── Widgets/
    └── ContinueListeningWidget.swift
```

---

## Feature Implementation Phases

### Phase 1: Bulletproof Foundation (Week 1-2)

**Goal**: App that never crashes, never loses progress

#### 1.1 Crash-Proof Architecture
- [x] Persist playback state to disk every 5 seconds
- [x] On launch: check for interrupted session, auto-resume
- [x] Proper error boundaries around all async operations
- [x] Graceful degradation when server unreachable

#### 1.2 Authentication
- [x] Server URL entry with validation & discovery
- [x] Login with secure Keychain token storage
- [x] Token refresh with retry logic
- [x] Session persistence across app restarts

#### 1.3 Library (Fast & Searchable)
- [x] Library grid with cover caching
- [x] **Alphabet scrubber** for quick navigation
- [x] Fast local search (not server-dependent)
- [x] Pull-to-refresh with smooth animation

### Phase 2: Rock-Solid Playback (Week 3-4)

**Goal**: Playback that works everywhere, every time

#### 2.1 Audio Engine
- [x] AVPlayer with proper error recovery
- [x] Seeking that works (investigate iOS bug)
- [x] Background audio that never stops
- [x] Proper interruption handling (calls, Siri)

#### 2.2 Remote Controls
- [x] Lock screen controls (play/pause/seek)
- [x] Control Center integration
- [x] **Headphone button mapping** (single, double, triple tap)
- [x] CarPlay basic support

#### 2.3 Sleep Timer
- [x] Timer with fade-out effect
- [x] **Auto-restart when resuming** (BookPlayer-style)
- [x] Save progress before sleep activates
- [ ] Shake to extend timer (needs motion detection)

### Phase 3: Smart Features (Week 5-6)

**Goal**: Features that make listening effortless

#### 3.1 Auto-Resume
- [x] Settings: "Auto-play last book on launch"
- [x] Remember exact position across devices
- [x] "Continue Listening" prominent on home

#### 3.2 Narrator & Author Browse
- [x] Dedicated Author tab with photo grids
- [ ] Dedicated Narrator tab (needs additional view)
- [x] "More by this author" on book detail

#### 3.3 Downloads & Storage
- [x] Background download queue
- [x] **Auto-download next in series** (setting)
- [x] Storage usage display
- [x] Auto-delete completed (optional setting)

### Phase 4: Premium Polish (Week 7-8)

**Goal**: App that feels like Apple made it

#### 4.1 Accessibility
- [x] Full VoiceOver support (AudioBooth standard)
- [x] Dynamic Type throughout
- [x] Reduce Motion support
- [ ] Accessibility audits (needs real testing)

#### 4.2 Bedroom Mode
- [x] OLED black theme
- [x] Dimmed controls
- [ ] Large tap targets in dark (needs refinement)
- [x] Optional auto-enable at night

#### 4.3 CarPlay Polish
- [x] Full library browsing
- [x] Now Playing screen
- [x] Chapter navigation in car
- [ ] Stable under all conditions (needs real testing)

#### 4.4 Micro-interactions
- [x] Haptic feedback (with toggle)
- [x] Spring animations
- [x] Smooth transitions
- [x] Loading skeletons

---

## Key Differentiators vs Competition

| Feature | ShelfPlayer | SoundLeaf | **Ears** |
|---------|-------------|-----------|----------|
| Crash recovery | ❌ Manual | ❌ Manual | ✅ Auto-resume |
| Auto-play on launch | ❌ | ❌ | ✅ Optional |
| Alphabet scrubber | ❌ | ❌ | ✅ |
| Narrator tab | ❌ | ❌ | ⏳ Planned |
| Sleep auto-restart | ❌ | ❌ | ✅ |
| Bedroom mode | ❌ | ❌ | ✅ |
| VoiceOver quality | ⚠️ Basic | ⚠️ Basic | ✅ Excellent |
| Headphone controls | ⚠️ Unreliable | ⚠️ | ✅ Fully mapped |

---

## API Integration

### Authentication Flow
```swift
// POST /login with x-return-tokens: true
// Store tokens in Keychain
// Refresh automatically when expired
```

### Key Endpoints
- `GET /api/me` - User profile
- `GET /api/libraries` - Libraries
- `GET /api/libraries/:id/items` - Books
- `GET /api/items/:id` - Book detail
- `GET /api/items/:id/cover` - Cover image
- `POST /api/items/:id/play` - Start session
- `POST /api/session/:id/sync` - Sync progress
- `PATCH /api/me/progress/:id` - Update progress

### Playback State Sync
```swift
// Save locally every 5 seconds
// Sync to server when:
//   - Position changes > 30 sec
//   - Pause/stop
//   - App backgrounds
//   - Chapter changes
```

---

## Verification Plan

1. **Stability**: Force-quit app during playback → Relaunch → Should resume exact position
2. **Background**: Lock phone → Audio continues → Lock screen controls work
3. **CarPlay**: Connect to CarPlay → Browse library → Play book → Chapter skip works
4. **Headphones**: AirPods connected → Double-tap skips chapter → Play/pause reliable
5. **Sleep Timer**: Set 5 min timer → Falls asleep → Resume via AirPods → Timer restarts
6. **Accessibility**: Enable VoiceOver → Navigate entire app → All controls labeled
7. **Large Library**: Load 500+ books → Scroll smooth → Alphabet scrubber works
8. **Offline**: Enable airplane mode → Downloaded books play → Queue progress syncs later

---

## Implementation Status

### Completed ✅
- [x] Project structure and Xcode project
- [x] App architecture (EarsApp, AppState, CrashRecovery)
- [x] Core Audio engine (AudioPlayer, AudioSession, NowPlayingInfo, RemoteCommands, SleepTimer)
- [x] Network layer (APIClient, all models)
- [x] Authentication flow (ServerSetup, Login, Keychain)
- [x] Library views (LibraryView with alphabet scrubber, BookGrid, BookDetail, Search, AuthorList)
- [x] Player views (NowPlaying, MiniPlayer, ChapterList, SleepTimer, SpeedControl)
- [x] Downloads & Storage management
- [x] Settings screens
- [x] CarPlay support
- [x] Accessibility features
- [x] Design System and Components

### Future Enhancements 🚀
- [ ] Widgets (Continue Listening widget)
- [ ] Dedicated Narrator browse tab
- [ ] Shake to extend sleep timer
- [ ] Podcast support
- [ ] iCloud sync for settings
- [ ] Apple Watch companion app
- [ ] Siri Shortcuts integration

---

## Sources

- [Audiobookshelf App Discussion #864](https://github.com/advplyr/audiobookshelf-app/discussions/864) - Power user feedback
- [ShelfPlayer Issues](https://github.com/rasmuslos/ShelfPlayer/issues) - Bug reports
- [SoundLeaf](https://soundleafapp.com/) - iOS client
- [BookPlayer](https://apps.apple.com/us/app/bookplayer/id1138219998) - Auto-sleep inspiration
- [AudioBooth AppleVis](https://www.applevis.com/apps/ios/books/audiobooth-audiobooks-player) - Accessibility gold standard
- [Still App](https://github.com/7enChan/stillapp) - Minimalist philosophy
