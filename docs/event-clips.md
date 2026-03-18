# Event Clips & Timeline

## Overview

Automatically saves a ~30-second video clip and thumbnail when a bark or whine is detected. Clips are displayed in a scrollable timeline in the viewer UI and can be played back in a fullscreen modal.

## Server-Side

### Segment Management

ffmpeg writes HLS segments to `stream/` with the `append_list` flag (no automatic deletion). The server runs its own cleanup interval every 4 seconds, keeping the most recent 30 segments (~60 seconds). This buffer ensures enough footage exists when an event triggers clip capture.

Segments being used by an active clip capture are protected from cleanup via the `activeCaptures` Set.

### Clip Capture (`captureClip()`)

Triggered from `POST /bark` when at least 15 seconds have elapsed since the last clip (configurable via `CLIP_COOLDOWN`).

Steps:
1. Reads available `.ts` segments from `stream/`, takes the most recent 15 (~30 seconds)
2. Writes a concat list file for ffmpeg
3. Concatenates segments into an MP4 using ffmpeg's concat demuxer (`-c copy`, no re-encoding — very fast)
4. Extracts a JPEG thumbnail from 1 second into the clip
5. Writes a metadata JSON file with id, type, confidence, timestamp, filenames, and duration
6. All three files (`.mp4`, `.jpg`, `.json`) are saved to `clips/`

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/clips` | GET | Returns JSON array of all clip metadata, newest first |
| `/clips/:file` | GET | Serves clip files (MP4, JPG) statically |

### Retention

A cleanup interval runs every 60 seconds. When clip count exceeds `MAX_CLIPS` (default: 50), the oldest clips are deleted (`.mp4`, `.jpg`, `.json` for each).

### SSE Integration

When a clip is successfully captured, the clip metadata is included in the SSE broadcast event as a `clip` property. Clients receiving the event can immediately render the new clip card without polling.

## Client-Side

### Timeline UI

A horizontally scrollable row of clip cards below the "Recent Activity" log. Each card shows:
- Thumbnail image
- Event type (BARK in red, WHINE in yellow)
- Timestamp

### Clip Playback

Clicking a card opens a fullscreen modal overlay with the clip video and native playback controls. Click the X button or outside the video to close.

### Real-Time Updates

- On page load, existing clips are fetched from `GET /api/clips` and rendered
- New clips arriving via SSE are prepended to the timeline immediately
- DOM is capped at 50 clip cards

## Configuration

| Constant | Default | Location | Purpose |
|----------|---------|----------|---------|
| `MAX_SEGMENTS` | 30 | `server.js` | Segments kept in `stream/` (~60s buffer) |
| `MAX_CLIPS` | 50 | `server.js` | Maximum clips retained on disk |
| `CLIP_COOLDOWN` | 15000 ms | `server.js` | Minimum time between clip captures |
| Segments per clip | 15 | `server.js:captureClip` | Up to 30 seconds per clip |
