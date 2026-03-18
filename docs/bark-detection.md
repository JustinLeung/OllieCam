# Bark & Whine Detection

## Overview

Client-side audio analysis that detects dog barks and whines from the live stream audio, shows visual alerts, and broadcasts events to all connected viewers via SSE.

## How It Works

### Audio Pipeline

When the user clicks the unmute button, an `AudioContext` is created and the video element's audio is routed through the Web Audio API:

```
video -> MediaElementSource -> AnalyserNode -> GainNode -> speakers
```

The `AnalyserNode` provides FFT frequency data for detection. The `GainNode` controls mute/unmute. Detection runs regardless of mute state once the AudioContext is initialized.

### Bark Detection

Monitors energy in the **500-3000 Hz** band (typical bark frequencies). Triggers when:
- Energy spike exceeds rolling baseline by **>15 dB**
- Absolute energy is above **-45 dB**
- At least **3 seconds** since last detection

### Whine Detection

Monitors energy in the **300-5000 Hz** band (wider range for tonal whines). Triggers when:
- Energy exceeds baseline by **>8 dB** (lower threshold than barks)
- Absolute energy is above **-50 dB**
- Sustained for **15 consecutive frames** (~1.5 seconds)
- At least **5 seconds** since last detection

The whine frame counter decays by 1 per frame when below threshold, tolerating brief gaps in sustained whining.

## Event Flow

1. Client detects bark/whine via frequency analysis
2. Client shows local alert banner (red for bark, yellow for whine)
3. Client POSTs `{ type, confidence }` to `POST /bark`
4. Server logs the event and may trigger a clip capture (see [event-clips.md](event-clips.md))
5. Server broadcasts event to all SSE clients via `GET /events`
6. All connected viewers see the alert (deduped within 2 seconds)

## Tuning

Key constants are in the `startBarkDetection()` function in `public/index.html`:

| Parameter | Value | Purpose |
|-----------|-------|---------|
| Bark band | 500-3000 Hz | Frequency range for bark energy |
| Whine band | 300-5000 Hz | Frequency range for whine energy |
| Bark spike threshold | 15 dB | Minimum spike above baseline |
| Whine spike threshold | 8 dB | Minimum sustained spike |
| Bark absolute threshold | -45 dB | Minimum absolute energy |
| Whine absolute threshold | -50 dB | Minimum absolute energy |
| Bark cooldown | 3000 ms | Minimum time between bark detections |
| Whine cooldown | 5000 ms | Minimum time between whine detections |
| Whine sustained frames | 15 | ~1.5s of sustained energy required |
| Analysis interval | 100 ms | Frequency analysis runs every 100ms |
| Rolling baseline window | 50 frames | ~5 seconds of energy history |

## Limitations

- Detection only runs when at least one viewer has clicked unmute (browser requires user gesture for AudioContext)
- Frequency-based analysis, not ML-based classification — may have false positives from other sounds in the bark/whine frequency range
- Accuracy depends on microphone quality and ambient noise levels
