# Feature Roadmap

## Quick Wins

### Pre-Recorded Sound Playback
Buttons to play pre-recorded audio clips ("Good boy!", "No!", treat-call sounds) through the Mac speakers via `afplay`. Upload clips to the server, add a `POST /play-sound` endpoint.

## High Impact

### Two-Way Audio
A "talk" button that captures the viewer's mic via `getUserMedia()` and plays it through the Mac speakers. Requires WebSocket or WebRTC for low-latency audio transport. Most-promoted feature across Furbo, Petcube, Wyze, and Blink.

### Motion Detection
Server-side frame differencing to detect movement. Use ffmpeg's scene-change detection or periodic snapshot comparison with `pixelmatch`/`sharp`. Hook into the existing SSE broadcast for alerts.

### ~~Push Notifications~~ Done
Implemented via ntfy.sh. Server sends push notifications on bark/whine events with configurable cooldown. iOS Settings UI auto-discovers ntfy config from server. See `docs/push-notifications.md`.

## Nice to Have

### ~~Night Vision Enhancement~~ Done
Implemented as a manual toggle. `POST /api/nightvision` toggles the ffmpeg `eq` filter (brightness=0.1, contrast=1.5, gamma=2.0) and restarts the encoder. State syncs across all viewers via SSE. See `docs/night-vision.md`.

### Continuous Recording with Playback
Archive HLS segments to a `recordings/` directory instead of deleting them. Build a playback endpoint for time-range queries. ~350 MB/hour at 720p/800kbps — needs retention/cleanup logic.

### Activity Zones
Let the user draw rectangles on the video to define regions of interest. Only trigger motion alerts when movement occurs within those zones. Reduces false positives from curtains, shadows, fans.

### Daily Activity Summary
Persist events to SQLite or a JSON file. Generate daily summaries: total barks/whines, peak activity periods, quiet stretches. Expose via `GET /summary?date=YYYY-MM-DD` and a summary UI card. Optional email digest via nodemailer.
