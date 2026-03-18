# OllieCam

Live dog cam that streams video and audio from a Mac's camera over the web, with real-time bark and whine detection.

Built with Node.js, ffmpeg (HLS), and hls.js.

## Features

- Live video + audio streaming via HLS with adaptive bitrate (720p/480p/360p)
- ~3-4 second end-to-end latency
- Server-side bark/whine detection with FFT analysis and noise isolation
- Real-time alerts broadcast to all viewers via Server-Sent Events
- Event clips: auto-saved ~30s video clips on bark/whine detection
- Screenshot download from live stream
- Live viewer count
- Play/pause with live snapshot preview
- Native iOS client (Swift 6.2 + SwiftUI)
- Optional password protection
- Cloudflare Tunnel support for remote access

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

## Development

```bash
npm run dev
```

Runs the Express backend and Vite dev server with hot reloading. Open http://localhost:5173.

## Environment Variables

| Variable   | Default     | Description                                          |
|------------|-------------|------------------------------------------------------|
| `PORT`     | `3000`      | Server port                                          |
| `CAMERA`   | `0`         | AVFoundation video device index                      |
| `MIC`      | `default`   | AVFoundation audio device index (`none` to disable)  |
| `PASSWORD` | _(empty)_   | Set to enable HTTP Basic Auth                        |
| `ABR`      | `true`      | Adaptive bitrate streaming (`false` for single 720p) |
| `SERVER_URL` | `http://localhost:3000` | (detector only) Server URL to report events to |
| `DEBUG`    | _(empty)_   | (detector only) Set to `1` for live energy logging |

To list available devices:

```bash
ffmpeg -f avfoundation -list_devices true -i ""
```

## iOS Client

A native iOS app is available in `ios/`. Requires XcodeGen:

```bash
brew install xcodegen
cd ios && xcodegen generate
```

Then open `OllieCam.xcodeproj` in Xcode and run on an iOS 26+ device or simulator. See `docs/ios-client.md` for details.
