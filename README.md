# OllieCam

Live dog cam that streams video and audio from a Mac's camera over the web, with real-time bark and whine detection.

Built with Node.js, ffmpeg (HLS), and hls.js.

## Features

- Live video + audio streaming via HLS
- Bark and whine detection using Web Audio API frequency analysis
- Real-time alerts broadcast to all viewers via Server-Sent Events
- Play/pause with live snapshot preview
- Optional password protection
- Cloudflare Tunnel support for remote access

## Prerequisites

- Node.js
- ffmpeg (`brew install ffmpeg`)
- A Mac with a camera and microphone

## Quick Start

```bash
npm install
npm start
```

Open http://localhost:3000 and click play.

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

To list available devices:

```bash
ffmpeg -f avfoundation -list_devices true -i ""
```
