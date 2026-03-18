# Night Vision

Boosts brightness, contrast, and gamma via ffmpeg video filters for improved visibility in low-light conditions.

## How It Works

When enabled, the server injects an `eq` (equalization) filter into the ffmpeg encoding pipeline:

```
eq=brightness=0.1:contrast=1.5:gamma=2.0
```

- **brightness=0.1** — slight brightness boost (range: -1.0 to 1.0)
- **contrast=1.5** — 50% contrast increase (range: -1000 to 1000, default 1.0)
- **gamma=2.0** — doubles gamma, lifting dark areas significantly (range: 0.1 to 10.0, default 1.0)

Toggling night vision restarts the ffmpeg process with the updated filter chain. There is a brief stream interruption (~2-3 seconds) while the encoder restarts and new HLS segments are generated.

### ABR Mode

In ABR mode, the `eq` filter is prepended to the existing filter_complex before the split:

```
[0:v]eq=brightness=0.1:contrast=1.5:gamma=2.0[veq];[veq]split=3[v0][v1][v2];...
```

### Single Stream Mode

In non-ABR mode, a simple `-vf eq=...` flag is added to the ffmpeg arguments.

## API

### Get Status

```
GET /api/nightvision
```

Response:
```json
{ "enabled": false }
```

### Toggle

```
POST /api/nightvision
Content-Type: application/json

{ "enabled": true }
```

If `enabled` is omitted, toggles the current state. Response:
```json
{ "enabled": true }
```

## Client Integration

The web viewer shows a moon icon button in the control bar. Clicking it sends a `POST /api/nightvision` request. The button highlights green when active.

State is synced across all connected viewers via SSE:

```json
{ "type": "nightvision", "enabled": true }
```

## Tuning

To adjust the filter parameters, edit the `eq=` string in `server.js` (appears twice — once in the ABR filter_complex and once in the non-ABR `-vf` flag). Useful adjustments:

| Parameter  | Effect                        | Range          | Default |
|------------|-------------------------------|----------------|---------|
| brightness | Overall brightness shift      | -1.0 to 1.0    | 0       |
| contrast   | Contrast multiplier           | -1000 to 1000  | 1.0     |
| gamma      | Gamma correction (lifts darks)| 0.1 to 10.0    | 1.0     |
| saturation | Color saturation              | 0.0 to 3.0     | 1.0     |

Higher gamma values reveal more detail in shadows but can wash out highlights. For very dark environments, try `gamma=3.0` with `brightness=0.15`.
