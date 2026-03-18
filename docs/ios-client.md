# iOS Client

Native iOS app for monitoring OllieCam remotely with native HLS playback, client-side bark/whine detection, and real-time SSE alerts.

## Setup

1. Install XcodeGen: `brew install xcodegen`
2. Generate project: `cd ios && xcodegen generate`
3. Open `ios/OllieCam.xcodeproj` in Xcode
4. Build and run on iOS 26+ simulator or device

## Architecture

- **Swift 6.2 + SwiftUI**, targeting **iOS 26+**
- Strict Swift concurrency with `@Observable` + `@MainActor` ViewModels
- No third-party dependencies — AVPlayer for HLS, vDSP for FFT, URLSession for networking
- SwiftLint enforced via build phase

## Project Structure

```
ios/OllieCam/
  OllieCamApp.swift          -- @main entry point
  Models/                    -- DetectionType, BarkEvent, ClipMetadata, ServerConfiguration
  Services/                  -- APIClient, SSEClient, HLSPlayerService, AudioAnalysisService, FFTProcessor
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

### Bark/Whine Detection
- **MTAudioProcessingTap** on AVPlayerItem audio mix taps decoded PCM samples
- Lock-free ring buffer for real-time thread safety
- **vDSP FFT** (2048 bins) — exact port of web client detection:
  - Bark: 500–3000 Hz, spike >15 dB above baseline, >-45 dB absolute, 3s cooldown
  - Whine: 300–5000 Hz, spike >8 dB sustained 15 frames (~1.5s), >-50 dB absolute, 5s cooldown
  - Rolling baseline: 50-frame window (~5s)
- Detection continues even when muted

### SSE Real-Time Events
- URLSession.bytes async sequence, parses `data:` lines
- Exponential backoff reconnection (1s → 2s → 4s, cap 30s)
- 2-second dedup window (matches web client)

### Event Clips
- Horizontal scrollable timeline with thumbnail cards
- Type badge (bark/whine) + timestamp
- Tap to play in fullscreen sheet
- Auto-refreshes when SSE reports new clips

### Settings
- Server URL + optional password (stored in Keychain)
- Connection test with status indicator
- Shown on first launch if not configured

## Server API Usage

| Endpoint | iOS Usage |
|----------|-----------|
| `GET /stream/stream.m3u8` | AVPlayer HLS source |
| `GET /snapshot` | UIImage preview when paused |
| `GET /events` | SSE stream for real-time alerts |
| `POST /bark` | Report local detections |
| `GET /api/clips` | Load clip metadata list |
| `GET /clips/:file` | AsyncImage thumbnails, AVPlayer clip playback |

## Configuration

All detection thresholds are defined in `Constants.swift` and match the web client exactly. See `docs/bark-detection.md` for the algorithm details.
