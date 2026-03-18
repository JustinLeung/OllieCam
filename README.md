# OllieCam

Live dog cam that streams video and audio from a Mac's camera over the web, with real-time bark and whine detection.

Built with Node.js, ffmpeg (HLS), and hls.js. MIT licensed.

## Features

- Live video + audio streaming via HLS with adaptive bitrate (720p/480p/360p)
- ~3-4 second end-to-end latency
- Server-side bark/whine detection with FFT analysis, spectral contrast, and onset detection
- Real-time alerts broadcast to all viewers via Server-Sent Events
- Event clips: auto-saved ~30s video clips on bark/whine detection
- Screenshot download from live stream
- Live viewer count
- Play/pause with live snapshot preview
- Native iOS client (Swift 6.2 + SwiftUI)
- Optional password protection
- Cloudflare Tunnel support for remote access

## Architecture

```
Mac Camera/Mic
      |
      v
   ffmpeg ──> HLS segments (720p/480p/360p)
      |                |
      v                v
   server.js      detector.js
   (Express)      (FFT bark/whine detection)
      |                |
      |    POST /bark  |
      |<───────────────┘
      |
      v
   SSE broadcast ──> Web viewer (hls.js)
                 ──> iOS app (AVPlayer)
```

Two independent Node.js processes:

- **`server.js`** — Captures video via ffmpeg, serves HLS segments, handles SSE events, saves event clips
- **`detector.js`** — Captures audio via ffmpeg, runs real-time FFT analysis, reports bark/whine events to the server

## Prerequisites

- Node.js
- ffmpeg (`brew install ffmpeg`)
- A Mac with a camera and microphone

## Quick Start

```bash
npm install
npm run start:all
```

Open http://localhost:3000 and click play. This starts both the streaming server and the bark/whine detector.

To run just the server without detection: `npm start`

## Remote Access

To expose the cam over the internet via [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/):

```bash
npm run tunnel
```

## Bark/Whine Detection

The detector runs FFT analysis on mic audio every 100ms and detects:

- **Barks** (500-3000 Hz): sharp energy spikes with high spectral contrast and fast onset
- **Whines** (300-5000 Hz): sustained tonal energy above baseline for ~1.5 seconds

All thresholds are configurable via environment variables. Run `DEBUG=1 node detector.js` to see live energy levels for calibration. See `docs/detector.md` for the full tuning guide.

## Environment Variables

### Server

| Variable   | Default     | Description                                          |
|------------|-------------|------------------------------------------------------|
| `PORT`     | `3000`      | Server port                                          |
| `CAMERA`   | `0`         | AVFoundation video device index                      |
| `MIC`      | `default`   | AVFoundation audio device index (`none` to disable)  |
| `PASSWORD` | _(empty)_   | Set to enable HTTP Basic Auth                        |
| `ABR`      | `true`      | Adaptive bitrate streaming (`false` for single 720p) |

### Detector

| Variable   | Default     | Description                                          |
|------------|-------------|------------------------------------------------------|
| `SERVER_URL` | `http://localhost:3000` | Server URL to report events to            |
| `MIC`      | `default`   | AVFoundation audio device index                      |
| `PASSWORD` | _(empty)_   | Server password if auth is enabled                   |
| `DEBUG`    | _(empty)_   | Set to `1` for live energy level logging             |
| `BARK_SPIKE` | `25`      | Bark spike threshold (dB above baseline)             |
| `WHINE_SPIKE` | `12`     | Whine spike threshold (dB above baseline)            |

See `docs/detector.md` for the full list of tunable thresholds.

To list available audio/video devices:

```bash
ffmpeg -f avfoundation -list_devices true -i ""
```

## iOS Client

A native iOS app is available in `ios/`. Built with Swift 6.2 and SwiftUI, targeting iOS 26+.

```bash
brew install xcodegen
cd ios && xcodegen generate
```

Open `OllieCam.xcodeproj` in Xcode and run on a device or simulator. Features include HLS live streaming, real-time SSE alerts, event clips timeline, and Keychain-backed server configuration. See `docs/ios-client.md` for details.

## Project Structure

```
server.js              # Streaming server (Express + ffmpeg)
detector.js            # Standalone bark/whine detector
public/index.html      # Web viewer (single-page, embedded CSS/JS)
ios/                   # Native iOS client (Swift 6.2 + SwiftUI)
docs/                  # Feature documentation
stream/                # Runtime HLS segments (ephemeral)
clips/                 # Saved event clips (auto-cleaned)
```

## Documentation

- [HLS Streaming](docs/streaming.md) — encoding pipeline, segment management, client playback
- [Adaptive Bitrate](docs/adaptive-bitrate.md) — ABR variants, quality selector
- [Bark/Whine Detection](docs/bark-detection.md) — web client audio analysis algorithm
- [Detector](docs/detector.md) — server-side detector, calibration guide
- [Event Clips](docs/event-clips.md) — clip capture, timeline UI, retention
- [iOS Client](docs/ios-client.md) — setup, architecture, features

## License

[MIT](LICENSE)
