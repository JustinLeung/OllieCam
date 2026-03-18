# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

OllieCam — a live dog cam web app that captures video and audio from a Mac's camera/mic using ffmpeg, encodes it as HLS (HTTP Live Streaming), and serves it via an Express web server. Includes server-side bark/whine detection via a standalone detector process. Viewers watch the live stream in a browser using hls.js or the native iOS app.

## Commands

- **Start the server:** `npm start` (runs `node server.js`)
- **Start the detector:** `npm run detect` (runs `node detector.js`)
- **Start both:** `npm run start:all`
- **Prerequisite:** ffmpeg must be installed (`brew install ffmpeg`)

## Environment Variables

- `PORT` — Server port (default: 3000)
- `CAMERA` — AVFoundation video device index (default: "0")
- `MIC` — AVFoundation audio device index (default: "default"; set to "none" to disable audio)
- `PASSWORD` — If set, enables HTTP Basic Auth on all routes
- `ABR` — Adaptive bitrate streaming (default: "true"; set to "false" for single 720p stream)
- `SERVER_URL` — (detector.js only) OllieCam server URL (default: "http://localhost:3000")

## Architecture

Two independent Node.js processes:

1. **Streaming server** (`server.js`) — Express HTTP server + ffmpeg child process for video/audio capture. ffmpeg encodes HLS with ABR variants (720p/480p/360p). Serves HLS segments, static viewer page, snapshot (`GET /snapshot`), SSE (`GET /events`), bark reporting (`POST /bark`), clips API (`GET /api/clips`), and clip files (`/clips/`). Captures event clips on `POST /bark` and broadcasts via SSE.

2. **Detector** (`detector.js`) — Standalone process that captures audio from the Mac mic via a separate ffmpeg instance, performs real-time FFT-based bark/whine detection, and reports events to the server via `POST /bark`. Can run on the same machine or remotely. Uses the same detection algorithm and thresholds as the original web client (500-3000 Hz bark band, 300-5000 Hz whine band, rolling baseline, sustained-frame whine detection).

The viewer (`public/index.html`) uses hls.js for non-Safari browsers and native HLS for Safari. Layout: sticky top bar (app name, LIVE status badge, viewer count), 16:9 video container, dedicated control bar (Play/Pause, Mute, Screenshot download, Quality selector), activity feed with colored event icons and relative timestamps (collapsible to 3 items), and event clips horizontal timeline. Uses CSS custom properties for theming and responsive breakpoints at 480px/360px. Loads the master playlist (`/stream/master.m3u8`) for adaptive quality switching; hls.js auto-selects quality based on bandwidth, with an optional manual quality selector. Starts paused with a snapshot preview; clicking play begins live streaming. Clicking the video or the control bar pause button pauses and shows a fresh snapshot. Audio is routed through the Web Audio API (`createMediaElementSource` -> `AnalyserNode` -> `GainNode`) for volume control and sound detection. SSE events include bark/whine alerts and viewer count broadcasts (`{ type: "viewers", count }`).

See `docs/` for detailed feature documentation.

## Documentation Rules

- Always update CLAUDE.md when adding or changing features, architecture, endpoints, or environment variables.
- When implementing a new feature, create a corresponding `docs/<feature-name>.md` file explaining how the feature works, its server/client components, configuration, and any tuning parameters.
- When changing tunable parameters (segment duration, thresholds, buffer sizes, etc.), update all docs that reference those values — check `docs/streaming.md`, `docs/adaptive-bitrate.md`, `docs/event-clips.md`, and `docs/detector.md`.
- Keep `FEATURES.md` up to date — mark features as completed when implemented and add new ideas as they come up.
- Keep `README.md` in sync with any user-facing changes (new commands, env vars, features).
- Keep iOS documentation accurate — `docs/ios-client.md` and the iOS section of this file must reflect what the Swift code actually implements. Do not document planned-but-unimplemented iOS features as if they exist.

## Key Files

- `server.js` — Streaming server (ffmpeg management, Express routes, auth, SSE, clip capture, segment cleanup)
- `detector.js` — Standalone bark/whine detector (ffmpeg audio capture, FFT analysis, reports to server)
- `public/index.html` — Single-page viewer with embedded CSS and JS (top bar, video player, control bar, activity feed, event clips timeline, screenshot download)
- `stream/` — Runtime directory for HLS master playlist and variant subdirectories (`720p/`, `480p/`, `360p/`) containing segments (`.ts`) and playlists (`.m3u8`); contents are ephemeral
- `clips/` — Saved event clips (`.mp4`), thumbnails (`.jpg`), and metadata (`.json`); auto-cleaned to 50 most recent
- `docs/` — Feature documentation
- `ios/` — Native iOS client (Swift 6.2 + SwiftUI, iOS 26+)

## iOS Client

Native iOS app in `ios/`. Uses XcodeGen (`project.yml`) — run `xcodegen generate` from `ios/` to create the Xcode project (`.xcodeproj` is gitignored).

### iOS Architecture
- **Swift 6.2 + SwiftUI**, targeting iOS 26+
- `@Observable` + `@MainActor` ViewModels, strict concurrency
- AVPlayer + AVPlayerLayer (UIViewRepresentable) for HLS playback
- SSE via URLSession.bytes for real-time bark/whine alerts (detection runs server-side via `detector.js`)
- Keychain storage for server URL and password
- No third-party dependencies

### iOS Key Files
- `ios/project.yml` — XcodeGen spec
- `ios/OllieCam/OllieCamApp.swift` — App entry point
- `ios/OllieCam/Services/` — APIClient, SSEClient, HLSPlayerService
- `ios/OllieCam/ViewModels/` — LiveStreamViewModel, ClipsViewModel, SettingsViewModel
- `ios/OllieCam/Views/` — All SwiftUI views
- `ios/OllieCam/Utilities/` — Constants, KeychainHelper, Color extension
