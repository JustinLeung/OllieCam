# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

OllieCam — a live dog cam web app that captures video and audio from a Mac's camera/mic using ffmpeg, encodes it as HLS (HTTP Live Streaming), and serves it via an Express web server. Includes client-side bark/whine detection. Viewers watch the live stream in a browser using hls.js.

## Commands

- **Start the server:** `npm start` (runs `node server.js`)
- **Prerequisite:** ffmpeg must be installed (`brew install ffmpeg`)

## Environment Variables

- `PORT` — Server port (default: 3000)
- `CAMERA` — AVFoundation video device index (default: "0")
- `MIC` — AVFoundation audio device index (default: "default"; set to "none" to disable audio)
- `PASSWORD` — If set, enables HTTP Basic Auth on all routes

## Architecture

Single-process Node.js app with two responsibilities:

1. **ffmpeg child process** (`server.js:startFFmpeg`) — Captures video and audio from the Mac camera/mic via AVFoundation, encodes video to H.264 (ultrafast/zerolatency, 800kbps) and audio to AAC (128kbps mono), and writes 2-second HLS segments to the `stream/` directory. Server-side cleanup keeps the last 30 segments (~60s). Auto-restarts on crash after 3 seconds.

2. **Express HTTP server** (`server.js`) — Serves HLS segments, static viewer page, snapshot endpoint (`GET /snapshot`), SSE (`GET /events`), bark/whine reporting (`POST /bark`), event clips API (`GET /api/clips`), and clip files (`/clips/`).

The viewer (`public/index.html`) uses hls.js for non-Safari browsers and native HLS for Safari. Starts paused with a snapshot preview; clicking play begins live streaming. Clicking the video pauses and shows a fresh snapshot. Audio is routed through the Web Audio API (`createMediaElementSource` -> `AnalyserNode` -> `GainNode`) for volume control and sound detection.

See `docs/` for detailed feature documentation.

## Documentation Rules

- Always update CLAUDE.md when adding or changing features, architecture, endpoints, or environment variables.
- When implementing a new feature, create a corresponding `docs/<feature-name>.md` file explaining how the feature works, its server/client components, configuration, and any tuning parameters.
- Keep `FEATURES.md` up to date — mark features as completed when implemented and add new ideas as they come up.
- Keep `README.md` in sync with any user-facing changes (new commands, env vars, features).

## Key Files

- `server.js` — All server logic (ffmpeg management, Express routes, auth, SSE, clip capture, segment cleanup)
- `public/index.html` — Single-page viewer with embedded CSS and JS (HLS playback, play/pause, sound detection, bark alert UI, event clips timeline)
- `stream/` — Runtime directory for HLS segments (`.ts`) and playlist (`.m3u8`); contents are ephemeral
- `clips/` — Saved event clips (`.mp4`), thumbnails (`.jpg`), and metadata (`.json`); auto-cleaned to 50 most recent
- `docs/` — Feature documentation
