# Adaptive Bitrate Streaming

HLS adaptive bitrate (ABR) streaming encodes the camera feed into multiple quality variants simultaneously. The client (hls.js) automatically switches between variants based on available bandwidth, or the viewer can manually select a quality level.

## How It Works

### Server Side

A single ffmpeg process captures from the Mac camera and uses `filter_complex` to split the video into three quality variants:

| Variant | Resolution | Video Bitrate | Audio Bitrate | Total Bandwidth |
|---------|-----------|---------------|---------------|-----------------|
| 720p    | 1280x720  | 800 kbps      | 128 kbps      | ~928 kbps       |
| 480p    | 854x480   | 400 kbps      | 96 kbps       | ~496 kbps       |
| 360p    | 640x360   | 200 kbps      | 64 kbps       | ~264 kbps       |

Each variant writes HLS segments to its own subdirectory under `stream/`:

```
stream/
  master.m3u8          # master playlist referencing all variants
  720p/
    stream.m3u8        # variant playlist
    seg000.ts, ...     # 2-second segments
  480p/
    stream.m3u8
    seg000.ts, ...
  360p/
    stream.m3u8
    seg000.ts, ...
```

The master playlist (`stream/master.m3u8`) is a standard HLS multivariant playlist that lists each variant with its bandwidth and resolution. hls.js and Safari's native HLS player both use this to select the appropriate quality.

### Client Side

- **hls.js (non-Safari)**: Parses the master playlist, starts with a lower quality, and switches up as bandwidth allows. A quality selector button appears in the video controls allowing the viewer to override auto selection or force a specific quality.
- **Safari**: Uses native HLS with automatic quality adaptation. No manual quality selector (Safari handles this internally).

### Segment Cleanup

Server-side cleanup runs every 4 seconds and removes old segments from all variant directories, keeping the most recent 30 segments (~60 seconds) per variant. Segments involved in active clip capture are protected from deletion.

### Snapshots and Clips

Both the `/snapshot` endpoint and clip capture use segments from the highest quality variant (720p) to ensure the best image/video quality.

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `ABR`    | `true`  | Set to `false` to disable adaptive bitrate and use a single 720p stream |

When `ABR=false`, the server falls back to the original single-stream behavior (720p @ 800kbps) with a master playlist containing one entry.

## CPU Impact

Encoding three variants simultaneously requires roughly 2-3x the CPU of a single stream, since each variant runs an independent H.264 encode (all using `ultrafast` preset). On modern Macs this is typically manageable, but on older hardware you may want to set `ABR=false`.

## Quality Selector UI

When multiple quality levels are available, a quality button appears in the bottom-right of the video player (to the left of the mute button). Clicking it opens a menu with options:

- **Auto** — hls.js selects quality based on bandwidth (default)
- **720p / 480p / 360p** — force a specific quality level

In auto mode, the button displays the current quality (e.g., "Auto (480p)"). In manual mode, it shows just the selected quality (e.g., "720p").
