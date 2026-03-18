# Push Notifications

Push notifications alert the owner when barking or whining is detected, even when the app is not open. Uses [ntfy.sh](https://ntfy.sh) — a free, open-source push notification service.

## How It Works

```
Bark detected → server.js → POST to ntfy.sh/your-topic → APNs → iOS notification
```

The server sends an HTTP POST to ntfy.sh whenever a bark or whine event fires (throttled). The ntfy iOS app subscribes to the same topic and delivers native iOS push notifications via APNs.

## Setup

### 1. Choose a unique topic name

Pick something hard to guess (it acts as a shared secret):

```bash
# Example: olliecam-abc123
export NTFY_TOPIC=olliecam-$(openssl rand -hex 4)
```

### 2. Start the server with the topic

```bash
NTFY_TOPIC=olliecam-abc123 npm run start:all
```

### 3. Install ntfy on your phone

- [ntfy iOS app](https://apps.apple.com/app/ntfy/id1625396347) (free)
- Subscribe to your topic name (e.g., `olliecam-abc123`)

### 4. Verify

Send a test notification from the OllieCam iOS app (Settings > Notifications > Send Test Notification) or via curl:

```bash
curl -X POST http://localhost:3000/api/notifications/test
```

## Server Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `NTFY_TOPIC` | _(empty)_ | ntfy topic name. Push notifications are disabled if unset. |
| `NTFY_SERVER` | `https://ntfy.sh` | ntfy server URL. Change for self-hosted instances. |
| `NTFY_TOKEN` | _(empty)_ | Access token for private topics (optional). |
| `NTFY_COOLDOWN` | `60000` | Minimum ms between push notifications (default: 1 minute). |

## Throttling

Push notifications have their own cooldown (`NTFY_COOLDOWN`, default 60 seconds), separate from:
- Clip capture cooldown (15 seconds)
- SSE broadcast (no cooldown)

This prevents notification fatigue when a dog barks repeatedly. The first bark triggers a push; subsequent barks within the cooldown period are still broadcast via SSE and may generate clips, but no additional push is sent.

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/notifications/config` | GET | Returns `{ enabled, topic, server }` for client auto-discovery |
| `/api/notifications/test` | POST | Sends a test notification to the configured topic |

## Notification Content

| Field | Bark | Whine |
|-------|------|-------|
| Title | OllieCam | OllieCam |
| Message | Bark detected (85% confidence) | Whine detected (72% confidence) |
| Priority | high | default |
| Tags | dog | dog |

## iOS App Integration

The OllieCam iOS app auto-discovers the ntfy configuration from the server via `GET /api/notifications/config`. The Settings screen shows:
- Whether push notifications are enabled on the server
- The configured topic name
- A "Send Test Notification" button
- A "Detect from Server" button to refresh the configuration

## Private Topics

For additional security, ntfy supports access tokens:

1. Create a token at ntfy.sh (or on your self-hosted instance)
2. Set `NTFY_TOKEN` on the server
3. Use the same token when subscribing in the ntfy iOS app

## Self-Hosting

ntfy can be self-hosted for full control:

```bash
# Docker
docker run -p 2586:80 binwiederhier/ntfy serve

# Then configure
NTFY_SERVER=http://localhost:2586 NTFY_TOPIC=olliecam npm run start:all
```

See [ntfy docs](https://docs.ntfy.sh) for full self-hosting instructions.
