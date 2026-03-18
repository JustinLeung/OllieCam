const express = require("express");
const { spawn } = require("child_process");
const path = require("path");
const fs = require("fs");

const PORT = process.env.PORT || 3000;
const CAMERA = process.env.CAMERA || "0";   // AVFoundation video device index
const MIC = process.env.MIC || "default";    // AVFoundation audio device index (or "none" to disable)
const PASSWORD = process.env.PASSWORD || ""; // Set to require basic auth
const HLS_DIR = path.join(__dirname, "stream");
const CLIPS_DIR = path.join(__dirname, "clips");
const MAX_SEGMENTS = 30;  // keep ~60s of segments for clip capture
const MAX_CLIPS = 50;     // retention limit
const CLIP_COOLDOWN = 15000; // minimum 15s between clips

// Ensure directories exist
if (!fs.existsSync(HLS_DIR)) fs.mkdirSync(HLS_DIR);
if (!fs.existsSync(CLIPS_DIR)) fs.mkdirSync(CLIPS_DIR);

const app = express();

// Optional basic auth
if (PASSWORD) {
  app.use((req, res, next) => {
    const auth = req.headers.authorization;
    if (!auth || !auth.startsWith("Basic ")) {
      res.setHeader("WWW-Authenticate", 'Basic realm="OllieCam"');
      return res.status(401).send("Authentication required");
    }
    const decoded = Buffer.from(auth.split(" ")[1], "base64").toString();
    const [, pass] = decoded.split(":");
    if (pass !== PASSWORD) {
      res.setHeader("WWW-Authenticate", 'Basic realm="OllieCam"');
      return res.status(401).send("Invalid password");
    }
    next();
  });
  console.log("Password protection enabled");
}

// Serve HLS segments with correct CORS/content-type headers
app.use(
  "/stream",
  (req, res, next) => {
    res.setHeader("Access-Control-Allow-Origin", "*");
    if (req.path.endsWith(".m3u8")) {
      res.setHeader("Content-Type", "application/vnd.apple.mpegurl");
      res.setHeader("Cache-Control", "no-cache, no-store");
    } else if (req.path.endsWith(".ts")) {
      res.setHeader("Content-Type", "video/mp2t");
    }
    next();
  },
  express.static(HLS_DIR)
);

// Serve viewer page
app.use(express.static(path.join(__dirname, "public")));

// Snapshot: extract a frame from the latest HLS segment
app.get("/snapshot", (req, res) => {
  const files = fs.readdirSync(HLS_DIR)
    .filter(f => f.endsWith(".ts"))
    .sort();
  if (files.length === 0) {
    return res.status(503).send("No segments yet");
  }
  const latest = path.join(HLS_DIR, files[files.length - 1]);
  const ff = spawn("ffmpeg", [
    "-i", latest,
    "-frames:v", "1",
    "-f", "image2",
    "-c:v", "mjpeg",
    "-q:v", "3",
    "pipe:1",
  ], { stdio: ["ignore", "pipe", "pipe"] });

  res.setHeader("Content-Type", "image/jpeg");
  res.setHeader("Cache-Control", "no-cache");
  ff.stdout.pipe(res);
  ff.on("error", () => res.status(500).end());
});

// Bark detection events
app.use(express.json());
const sseClients = new Set();

app.get("/events", (req, res) => {
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.flushHeaders();
  sseClients.add(res);
  req.on("close", () => sseClients.delete(res));
});

// --- Clip capture ---
const activeCaptures = new Set();
let lastClipTime = 0;

function captureClip(eventType, confidence) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const clipId = `${eventType}_${timestamp}`;
  const clipPath = path.join(CLIPS_DIR, `${clipId}.mp4`);
  const thumbPath = path.join(CLIPS_DIR, `${clipId}.jpg`);
  const metaPath = path.join(CLIPS_DIR, `${clipId}.json`);

  const segments = fs.readdirSync(HLS_DIR)
    .filter(f => f.endsWith(".ts"))
    .sort();
  if (segments.length === 0) return Promise.resolve(null);

  const clipSegments = segments.slice(-15); // up to 30s
  for (const seg of clipSegments) activeCaptures.add(seg);

  const concatFile = path.join(CLIPS_DIR, `${clipId}_concat.txt`);
  const concatList = clipSegments
    .map(s => `file '${path.join(HLS_DIR, s)}'`)
    .join("\n");
  fs.writeFileSync(concatFile, concatList);

  return new Promise((resolve) => {
    const ff = spawn("ffmpeg", [
      "-f", "concat", "-safe", "0",
      "-i", concatFile,
      "-c", "copy",
      "-movflags", "+faststart",
      clipPath,
    ], { stdio: ["ignore", "pipe", "pipe"] });

    ff.on("close", (code) => {
      try { fs.unlinkSync(concatFile); } catch {}
      for (const seg of clipSegments) activeCaptures.delete(seg);

      if (code !== 0) return resolve(null);

      // Extract thumbnail
      const thumbFf = spawn("ffmpeg", [
        "-i", clipPath,
        "-ss", "1",
        "-frames:v", "1",
        "-q:v", "3",
        thumbPath,
      ], { stdio: ["ignore", "pipe", "pipe"] });

      thumbFf.on("close", () => {
        const meta = {
          id: clipId,
          type: eventType,
          confidence,
          timestamp: new Date().toISOString(),
          clip: `${clipId}.mp4`,
          thumbnail: `${clipId}.jpg`,
          duration: clipSegments.length * 2,
        };
        fs.writeFileSync(metaPath, JSON.stringify(meta));
        resolve(meta);
      });
    });
  });
}

app.post("/bark", (req, res) => {
  const type = req.body.type === "whine" ? "whine" : "bark";
  const event = {
    type,
    confidence: req.body.confidence,
    timestamp: new Date().toISOString(),
  };
  const label = type === "whine" ? "WHINE" : "BARK";
  console.log(`[${label}] ${event.timestamp} (confidence: ${(event.confidence * 100).toFixed(0)}%)`);

  const now = Date.now();
  if (now - lastClipTime > CLIP_COOLDOWN) {
    lastClipTime = now;
    captureClip(type, req.body.confidence).then((meta) => {
      if (meta) {
        console.log(`[CLIP] Saved ${meta.clip} (${meta.duration}s)`);
        event.clip = meta;
      }
      for (const client of sseClients) {
        client.write(`data: ${JSON.stringify(event)}\n\n`);
      }
    });
  } else {
    for (const client of sseClients) {
      client.write(`data: ${JSON.stringify(event)}\n\n`);
    }
  }
  res.json({ ok: true });
});

// --- Clips API ---
app.get("/api/clips", (req, res) => {
  const clips = fs.readdirSync(CLIPS_DIR)
    .filter(f => f.endsWith(".json"))
    .sort()
    .reverse()
    .map(f => {
      try { return JSON.parse(fs.readFileSync(path.join(CLIPS_DIR, f), "utf-8")); }
      catch { return null; }
    })
    .filter(Boolean);
  res.json(clips);
});

app.use("/clips", express.static(CLIPS_DIR));

// Start ffmpeg capture
function startFFmpeg() {
  // Clean old segments
  for (const f of fs.readdirSync(HLS_DIR)) {
    fs.unlinkSync(path.join(HLS_DIR, f));
  }

  const audioInput = MIC === "none" ? "none" : MIC;
  const args = [
    "-f", "avfoundation",
    "-framerate", "30",
    "-video_size", "1280x720",
    "-i", `${CAMERA}:${audioInput}`,
    "-c:v", "libx264",
    "-preset", "ultrafast",
    "-tune", "zerolatency",
    "-b:v", "800k",       // cap bitrate for smoother streaming over tunnel
    "-maxrate", "800k",
    "-bufsize", "1600k",
    "-g", "30",           // keyframe every 1s at 30fps
    "-sc_threshold", "0",
    ...(audioInput !== "none" ? [
      "-c:a", "aac",
      "-b:a", "128k",
      "-ac", "1",         // mono — sufficient for ambient audio
    ] : ["-an"]),
    "-f", "hls",
    "-hls_time", "2",     // 2-second segments — smoother over tunnel
    "-hls_list_size", "5",
    "-hls_flags", "append_list",  // server handles segment cleanup
    "-hls_segment_filename", path.join(HLS_DIR, "seg%03d.ts"),
    path.join(HLS_DIR, "stream.m3u8"),
  ];

  console.log("Starting camera capture...");
  const ffmpeg = spawn("ffmpeg", args, { stdio: ["ignore", "pipe", "pipe"] });

  ffmpeg.stderr.on("data", (data) => {
    const msg = data.toString();
    // Only log important messages, not frame-by-frame stats
    if (msg.includes("Error") || msg.includes("error") || msg.includes("Opening")) {
      console.error("[ffmpeg]", msg.trim());
    }
  });

  ffmpeg.on("close", (code) => {
    console.error(`ffmpeg exited with code ${code}, restarting in 3s...`);
    setTimeout(startFFmpeg, 3000);
  });

  return ffmpeg;
}

const ffmpegProcess = startFFmpeg();

// Server-side segment cleanup (replaces ffmpeg's delete_segments)
setInterval(() => {
  const segments = fs.readdirSync(HLS_DIR)
    .filter(f => f.endsWith(".ts"))
    .sort();
  if (segments.length > MAX_SEGMENTS) {
    const toDelete = segments
      .slice(0, segments.length - MAX_SEGMENTS)
      .filter(seg => !activeCaptures.has(seg));
    for (const seg of toDelete) {
      try { fs.unlinkSync(path.join(HLS_DIR, seg)); } catch {}
    }
  }
}, 4000);

// Clips retention cleanup
setInterval(() => {
  const metaFiles = fs.readdirSync(CLIPS_DIR)
    .filter(f => f.endsWith(".json"))
    .sort();
  if (metaFiles.length > MAX_CLIPS) {
    const toRemove = metaFiles.slice(0, metaFiles.length - MAX_CLIPS);
    for (const metaFile of toRemove) {
      const base = metaFile.replace(".json", "");
      for (const ext of [".json", ".mp4", ".jpg"]) {
        try { fs.unlinkSync(path.join(CLIPS_DIR, base + ext)); } catch {}
      }
    }
    console.log(`[CLEANUP] Removed ${toRemove.length} old clips`);
  }
}, 60000);

app.listen(PORT, () => {
  console.log(`\n  OllieCam running at http://localhost:${PORT}`);
  if (PASSWORD) {
    console.log(`  Password: ${PASSWORD}`);
  }
  console.log(`  Camera device: ${CAMERA}\n`);
});

// Cleanup on exit
function cleanup() {
  ffmpegProcess.kill("SIGTERM");
  process.exit();
}
process.on("SIGINT", cleanup);
process.on("SIGTERM", cleanup);
