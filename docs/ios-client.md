# iOS Client

Native iOS app for monitoring OllieCam remotely with native HLS playback, real-time SSE alerts, and event clips timeline.

## Setup

1. Install XcodeGen: `brew install xcodegen`
2. Generate project: `cd ios && xcodegen generate`
3. Open `ios/OllieCam.xcodeproj` in Xcode
4. Build and run on iOS 26+ simulator or device

## Architecture

- **Swift 6.2 + SwiftUI**, targeting **iOS 26+**
- Strict Swift concurrency with `@Observable` + `@MainActor` ViewModels
- No third-party dependencies — AVPlayer for HLS, URLSession for networking
- SwiftLint enforced via build phase

## Project Structure

```
ios/OllieCam/
  OllieCamApp.swift          -- @main entry point
  Models/                    -- DetectionType, BarkEvent, ClipMetadata, ServerConfiguration
  Services/                  -- APIClient, SSEClient, HLSPlayerService
  ViewModels/                -- LiveStreamViewModel, ClipsViewModel, SettingsViewModel
  Views/                     -- All SwiftUI views
  Utilities/                 -- Constants, KeychainHelper, Color extension
```

## Features

### Live HLS Streaming
- AVPlayer + AVPlayerLayer via UIViewRepresentable
- Auth headers passed via `AVURLAssetHTTPHeaderFieldsKey`
- Starts paused with `/snapshot` preview, tap play to stream, tap video to pause
- Seek-to-live button for catching up

### Real-Time Alerts (SSE)
- URLSession.bytes async sequence, parses `data:` lines
- Receives bark/whine events detected by the server-side detector (`detector.js`)
- Exponential backoff reconnection (1s -> 2s -> 4s, cap 30s)
- 2-second dedup window (matches web client)
- Bark detection does NOT run on-device — all detection is handled server-side by the standalone detector process and delivered to the iOS app via SSE

### Event Clips
- Horizontal scrollable timeline with thumbnail cards
- Type badge (bark/whine) + timestamp
- Tap to play in fullscreen sheet
- Auto-refreshes when SSE reports new clips

### Settings
- Server URL + optional password (stored in Keychain via `KeychainHelper`)
- Connection test with status indicator
- Push notification status auto-detected from server (`GET /api/notifications/config`)
- Send test notification button
- Shown on first launch if not configured

## Server API Usage

| Endpoint | iOS Usage |
|----------|-----------|
| `GET /stream/master.m3u8` | AVPlayer HLS source (ABR master playlist) |
| `GET /snapshot` | UIImage preview when paused |
| `GET /events` | SSE stream for real-time bark/whine/viewer alerts |
| `GET /api/clips` | Load clip metadata list |
| `GET /clips/:file` | AsyncImage thumbnails, AVPlayer clip playback |
| `GET /api/notifications/config` | Auto-discover ntfy push notification settings |
| `POST /api/notifications/test` | Trigger a test push notification |

## Views

| View | Purpose |
|------|---------|
| `ContentView` | Root tab/navigation container |
| `LiveStreamView` | Main live stream view with video, status, activity log |
| `VideoPlayerView` | UIViewRepresentable wrapping AVPlayerLayer |
| `StatusIndicatorView` | LIVE/Paused/Offline badge |
| `AlertBannerView` | Bark/whine alert banner overlay |
| `ActivityLogView` | Scrollable event log with type icons and timestamps |
| `ClipsTimelineView` | Horizontal scroll of clip cards |
| `ClipCardView` | Individual clip thumbnail card |
| `ClipPlayerView` | Fullscreen clip playback sheet |
| `SettingsView` | Server URL, password, connection test |
