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

1. **ffmpeg child process** (`server.js:startFFmpeg`) — Captures video and audio from the Mac camera/mic via AVFoundation, encodes video to H.264 (ultrafast/zerolatency) and audio to AAC, and writes 1-second HLS segments to the `stream/` directory. Auto-restarts on crash after 3 seconds.

2. **Express HTTP server** (`server.js`) — Serves HLS segments from `stream/` with correct MIME types and CORS headers, serves the static viewer page from `public/`, and provides SSE (`GET /events`) and bark reporting (`POST /bark`) endpoints for real-time bark notifications across all connected viewers.

The viewer (`public/index.html`) uses hls.js for non-Safari browsers and native HLS for Safari. It polls for stream availability, then connects with low-latency HLS settings. Audio is routed through the Web Audio API (`createMediaElementSource` -> `AnalyserNode` -> `GainNode`) to enable both volume control and bark detection.

**Bark detection** runs client-side using the Web Audio API `AnalyserNode`. It monitors energy in the 500–3000Hz frequency band against a rolling baseline, triggering on spikes >15dB above baseline. Detection activates when the user first clicks unmute (browser requires a user gesture to start `AudioContext`). Detected barks are POSTed to the server and broadcast via SSE so all viewers (including muted ones) see alerts. Key tuning constants are in the `startBarkDetection()` function in `index.html`.

## Key Files

- `server.js` — All server logic (ffmpeg management, Express routes, auth middleware, SSE + bark event endpoints)
- `public/index.html` — Single-page viewer with embedded CSS and JS (HLS playback, Web Audio bark detection, bark alert UI + log)
- `stream/` — Runtime directory for HLS segments (`.ts`) and playlist (`.m3u8`); contents are ephemeral
