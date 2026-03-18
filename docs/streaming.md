# HLS Streaming

## Overview

Video and audio are captured from the Mac's camera and microphone using ffmpeg, encoded into HLS (HTTP Live Streaming) segments, and served over HTTP. The browser viewer uses hls.js (or native HLS on Safari) for playback.

## Encoding Pipeline

ffmpeg captures via AVFoundation and outputs HLS:

| Parameter | Value | Purpose |
|-----------|-------|---------|
| Video codec | H.264 (`libx264`) | Universal browser support |
| Preset | `ultrafast` | Minimize CPU usage |
| Tune | `zerolatency` | Reduce encoding latency |
| Bitrate | 800 kbps (capped) | Smooth delivery over tunnel |
| Resolution | 1280x720 | HD quality |
| Framerate | 30 fps | Smooth motion |
| Keyframe interval | 30 frames (1s) | Frequent seek points |
| Audio codec | AAC, 128kbps, mono | Lightweight audio |
| Segment duration | 2 seconds | Balance between latency and reliability |
| Playlist size | 5 segments | Compact live playlist |

## Segment Management

Segments are written to `stream/` with the `append_list` flag. The server handles deletion instead of ffmpeg, keeping the last 30 segments (~60 seconds) to support event clip capture.

## Client Playback

### Play/Pause

The viewer starts **paused** showing a snapshot from the camera (`GET /snapshot`). Clicking the play overlay starts live streaming. Clicking the video while live pauses it and shows a fresh snapshot.

### HLS Configuration

| Setting | Value | Purpose |
|---------|-------|---------|
| `liveSyncDurationCount` | 4 | Target 4 segments behind live edge |
| `liveMaxLatencyDurationCount` | 8 | Maximum 8 segments behind before seeking |
| `lowLatencyMode` | false | Prioritize smooth playback over low latency |
| `backBufferLength` | 30 | Keep 30 seconds of back buffer |

This results in ~8-16 seconds of buffered latency, which absorbs network jitter when streaming through Cloudflare Tunnel.

### Audio Routing

Once the user clicks unmute, audio is routed through the Web Audio API:

```
video -> MediaElementSource -> AnalyserNode -> GainNode -> speakers
```

`video.muted` is set to `false` at this point since audio output is controlled by the GainNode. The mute button toggles `gainNode.gain.value` between 0 and 1.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CAMERA` | `0` | AVFoundation video device index |
| `MIC` | `default` | AVFoundation audio device index (`none` to disable) |

List available devices: `ffmpeg -f avfoundation -list_devices true -i ""`

## Cloudflare Tunnel

`npm run tunnel` starts the Express server and a Cloudflare Tunnel (`cloudflared tunnel run dogcam`), making the cam available at `dogcam.zulatus.com`.
