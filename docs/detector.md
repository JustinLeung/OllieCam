# Bark/Whine Detector

Standalone process that captures audio from the Mac mic, performs real-time FFT analysis, and reports bark/whine events to the OllieCam server.

## Quick Start

```bash
# Start alongside the server
npm run start:all

# Or run independently
npm run detect

# With custom server URL
SERVER_URL=https://dogcam.example.com node detector.js
```

## How It Works

1. **Audio capture**: Spawns a separate ffmpeg process that reads from the Mac mic and outputs raw 32-bit float PCM at 44.1 kHz mono to stdout.
2. **FFT analysis**: Every 100ms, runs a 2048-bin FFT on the audio buffer and computes energy in dB across frequency bands.
3. **Detection**: Checks four conditions for bark, three for whine (see below). If all pass, reports to the server via `POST /bark`.
4. **Server handles the rest**: Broadcasts the event via SSE, captures a clip if cooldown allows, and all connected clients (web + iOS) receive the alert.

## Detection Algorithm

### Bark Detection (short loud bursts, 500–3000 Hz)

All five conditions must be true simultaneously:

| Condition | Default | Env Var | What it filters |
|-----------|---------|---------|-----------------|
| **Spike** > threshold | 25 dB | `BARK_SPIKE` | Energy in bark band must exceed the rolling baseline by this much |
| **Absolute** > threshold | -30 dB | `BARK_ABS` | Bark band energy must be above this floor (filters quiet sounds) |
| **Onset** > threshold | 15 dB | `BARK_ONSET` | Energy must rise sharply from recent frames (filters gradual music) |
| **Spectral contrast** > threshold | 5 dB | `BARK_CONTRAST` | Bark band must exceed energy outside the band (filters broadband noise) |
| **Cooldown** elapsed | 3000 ms | `BARK_COOLDOWN` | Minimum time between bark detections |

### Whine Detection (sustained tonal, 300–5000 Hz)

| Condition | Default | Env Var |
|-----------|---------|---------|
| **Spike** > threshold | 12 dB | `WHINE_SPIKE` |
| **Absolute** > threshold | -45 dB | `WHINE_ABS` |
| **Spectral contrast** > threshold | 5 dB | `WHINE_CONTRAST` |
| **Sustained** for N frames | 15 (~1.5s) | `WHINE_FRAMES` |
| **Cooldown** elapsed | 5000 ms | `WHINE_COOLDOWN` |

### Rolling Baseline

The detector maintains a rolling average of total energy over the last 50 frames (~5 seconds). This adapts to the ambient noise floor. A 5-second warmup period ensures the baseline is stable before any detections fire.

Configurable via `BASELINE_WINDOW` (number of frames).

## Calibration Guide

### Step 1: Observe ambient levels

Run the detector in debug mode in the environment where it will be deployed:

```bash
DEBUG=1 node detector.js
```

This prints energy levels every second:
```
[DBG] barkE=-55.2 contrast=12.3 onset=2.1 spike=8.4 baseline=-63.6
```

Note the typical values during:
- **Silence**: What is the baseline? What is barkE?
- **Normal ambient noise** (TV, music, conversation): How high do spike, onset, and contrast go?

### Step 2: Trigger a real bark

Have your dog bark (or play a recording of your dog barking near the mic). Note the values:
```
[TRIGGER] barkE=-18.5 contrast=14.2 onset=22.8 spike=42.1
[BARK] confidence: 100%
```

### Step 3: Set thresholds between ambient and bark

Set each threshold above the highest ambient value but below the bark value:

```bash
# Example: ambient spike peaks at 15, bark spike is 42
# Set threshold to 20 (above ambient, well below bark)
BARK_SPIKE=20 BARK_ONSET=12 BARK_ABS=-35 node detector.js
```

### Tuning Tips

| Problem | Solution |
|---------|----------|
| **False positives from music** | Increase `BARK_ONSET` (music has gradual changes, barks are sudden) |
| **False positives from TV/voices** | Increase `BARK_SPIKE` and `BARK_ABS` (voices are quieter than barks) |
| **Missing real barks** | Decrease `BARK_SPIKE` and `BARK_ONSET` |
| **Missing quiet whines** | Decrease `WHINE_SPIKE` and `WHINE_ABS` |
| **Too many whine alerts** | Increase `WHINE_FRAMES` (require longer sustained sound) |
| **Detections fire on startup** | Increase `BASELINE_WINDOW` for longer warmup |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MIC` | `default` | AVFoundation audio device index |
| `SERVER_URL` | `http://localhost:3000` | OllieCam server to report events to |
| `PASSWORD` | *(empty)* | Server password if auth is enabled |
| `DEBUG` | *(empty)* | Set to `1` for live energy level logging |
| `BARK_SPIKE` | `25` | Bark spike threshold (dB above baseline) |
| `BARK_ABS` | `-30` | Bark absolute energy threshold (dB) |
| `BARK_ONSET` | `15` | Bark onset sharpness threshold (dB) |
| `BARK_CONTRAST` | `5` | Bark spectral contrast threshold (dB) |
| `BARK_COOLDOWN` | `3000` | Minimum ms between bark detections |
| `WHINE_SPIKE` | `12` | Whine spike threshold (dB above baseline) |
| `WHINE_ABS` | `-45` | Whine absolute energy threshold (dB) |
| `WHINE_CONTRAST` | `5` | Whine spectral contrast threshold (dB) |
| `WHINE_FRAMES` | `15` | Sustained frames required for whine (~1.5s) |
| `WHINE_COOLDOWN` | `5000` | Minimum ms between whine detections |
| `BASELINE_WINDOW` | `50` | Rolling baseline frames (~5s) |

## Architecture

```
Mac Mic → ffmpeg (raw PCM) → detector.js (FFT + detection) → POST /bark → server.js (SSE + clips)
                                                                              ↓
                                                                     Web / iOS clients
```

The detector is fully independent of the streaming server. It can be stopped, restarted, or run on a different machine without affecting the live stream.
