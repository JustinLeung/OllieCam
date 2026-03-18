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

// Adaptive bitrate streaming (set ABR=false to use single 720p stream)
const ABR = (process.env.ABR || "true").toLowerCase() !== "false";
const VARIANTS = [
  { name: "720p", width: 1280, height: 720, vbr: 800, abr: 128 },
  { name: "480p", width: 854,  height: 480, vbr: 400, abr: 96 },
  { name: "360p", width: 640,  height: 360, vbr: 200, abr: 64 },
];

// Ensure directories exist
if (!fs.existsSync(HLS_DIR)) fs.mkdirSync(HLS_DIR);
if (ABR) {
  for (const v of VARIANTS) {
    const dir = path.join(HLS_DIR, v.name);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  }
}
if (!fs.existsSync(CLIPS_DIR)) fs.mkdirSync(CLIPS_DIR);

// Highest-quality segments directory (for snapshots + clips)
const SEGMENTS_DIR = ABR ? path.join(HLS_DIR, VARIANTS[0].name) : HLS_DIR;

// Write HLS master playlist referencing variant streams
function writeMasterPlaylist() {
  const hasAudio = MIC !== "none";
  const lines = ["#EXTM3U"];
  if (ABR) {
    for (const v of VARIANTS) {
      const bw = (v.vbr + (hasAudio ? v.abr : 0)) * 1000;
      lines.push(`#EXT-X-STREAM-INF:BANDWIDTH=${bw},RESOLUTION=${v.width}x${v.height},NAME="${v.name}"`);
      lines.push(`${v.name}/stream.m3u8`);
    }
  } else {
    const bw = hasAudio ? 928000 : 800000;
    lines.push(`#EXT-X-STREAM-INF:BANDWIDTH=${bw},RESOLUTION=1280x720`);
    lines.push("stream.m3u8");
  }
  fs.writeFileSync(path.join(HLS_DIR, "master.m3u8"), lines.join("\n") + "\n");
}

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
  const files = fs.readdirSync(SEGMENTS_DIR)
    .filter(f => f.endsWith(".ts"))
    .sort();
  if (files.length === 0) {
    return res.status(503).send("No segments yet");
  }
  const latest = path.join(SEGMENTS_DIR, files[files.length - 1]);
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

// SSE events
app.use(express.json());
const sseClients = new Set();

function broadcastViewerCount() {
  const data = JSON.stringify({ type: "viewers", count: sseClients.size });
  for (const client of sseClients) {
    try {
      client.write(`data: ${data}\n\n`);
    } catch {
      sseClients.delete(client);
    }
  }
}

app.get("/events", (req, res) => {
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.flushHeaders();
  sseClients.add(res);
  broadcastViewerCount();
  req.on("close", () => {
    sseClients.delete(res);
    broadcastViewerCount();
  });
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

  const segments = fs.readdirSync(SEGMENTS_DIR)
    .filter(f => f.endsWith(".ts"))
    .sort();
  if (segments.length === 0) return Promise.resolve(null);

  const clipSegments = segments.slice(-15); // up to 30s
  for (const seg of clipSegments) activeCaptures.add(seg);

  const concatFile = path.join(CLIPS_DIR, `${clipId}_concat.txt`);
  const concatList = clipSegments
    .map(s => `file '${path.join(SEGMENTS_DIR, s)}'`)
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

function broadcast(event) {
  const data = JSON.stringify(event);
  for (const client of sseClients) {
    try {
      client.write(`data: ${data}\n\n`);
    } catch {
      sseClients.delete(client);
    }
  }
}

app.post("/bark", (req, res) => {
  const type = req.body.type === "whine" ? "whine" : "bark";
  const confidence = req.body.confidence || 0.5;
  const event = {
    type,
    confidence,
    timestamp: new Date().toISOString(),
  };
  const label = type === "whine" ? "WHINE" : "BARK";
  console.log(`[${label}] ${event.timestamp} (confidence: ${(confidence * 100).toFixed(0)}%)`);

  const now = Date.now();
  if (now - lastClipTime > CLIP_COOLDOWN) {
    lastClipTime = now;
    captureClip(type, confidence).then((meta) => {
      if (meta) {
        console.log(`[CLIP] Saved ${meta.clip} (${meta.duration}s)`);
        event.clip = meta;
      }
      broadcast(event);
    });
  } else {
    broadcast(event);
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
  if (ABR) {
    for (const v of VARIANTS) {
      const dir = path.join(HLS_DIR, v.name);
      for (const f of fs.readdirSync(dir)) {
        fs.unlinkSync(path.join(dir, f));
      }
    }
  } else {
    for (const f of fs.readdirSync(HLS_DIR)) {
      if (f === "master.m3u8") continue;
      fs.unlinkSync(path.join(HLS_DIR, f));
    }
  }

  writeMasterPlaylist();

  const audioInput = MIC === "none" ? "none" : MIC;
  const hasAudio = audioInput !== "none";
  let args;

  if (ABR) {
    args = [
      "-f", "avfoundation",
      "-framerate", "30",
      "-video_size", "1280x720",
      "-i", `${CAMERA}:${audioInput}`,
    ];

    const numV = VARIANTS.length;
    const splits = VARIANTS.map((_, i) => `[v${i}]`).join("");
    let fc = `[0:v]split=${numV}${splits}`;
    for (let i = 1; i < numV; i++) {
      const v = VARIANTS[i];
      fc += `;[v${i}]scale=${v.width}:${v.height}[v${i}out]`;
    }
    args.push("-filter_complex", fc);

    for (let i = 0; i < numV; i++) {
      const v = VARIANTS[i];
      const videoLabel = i === 0 ? `[v${i}]` : `[v${i}out]`;
      const varDir = path.join(HLS_DIR, v.name);

      args.push("-map", videoLabel);
      if (hasAudio) args.push("-map", "0:a");

      args.push(
        "-c:v", "libx264",
        "-preset", "ultrafast",
        "-tune", "zerolatency",
        "-b:v", `${v.vbr}k`,
        "-maxrate", `${v.vbr}k`,
        "-bufsize", `${v.vbr * 2}k`,
        "-g", "30",
        "-sc_threshold", "0",
      );

      if (hasAudio) {
        args.push("-c:a", "aac", "-b:a", `${v.abr}k`, "-ac", "1");
      } else {
        args.push("-an");
      }

      args.push(
        "-f", "hls",
        "-hls_time", "2",
        "-hls_list_size", "5",
        "-hls_flags", "append_list",
        "-hls_segment_filename", path.join(varDir, "seg%03d.ts"),
        path.join(varDir, "stream.m3u8"),
      );
    }
  } else {
    args = [
      "-f", "avfoundation",
      "-framerate", "30",
      "-video_size", "1280x720",
      "-i", `${CAMERA}:${audioInput}`,
      "-c:v", "libx264",
      "-preset", "ultrafast",
      "-tune", "zerolatency",
      "-b:v", "800k",
      "-maxrate", "800k",
      "-bufsize", "1600k",
      "-g", "30",
      "-sc_threshold", "0",
      ...(hasAudio ? ["-c:a", "aac", "-b:a", "128k", "-ac", "1"] : ["-an"]),
      "-f", "hls",
      "-hls_time", "2",
      "-hls_list_size", "5",
      "-hls_flags", "append_list",
      "-hls_segment_filename", path.join(HLS_DIR, "seg%03d.ts"),
      path.join(HLS_DIR, "stream.m3u8"),
    ];
  }

  console.log(`Starting camera capture${ABR ? " (ABR: 720p/480p/360p)" : ""}...`);
  const ffmpeg = spawn("ffmpeg", args, { stdio: ["ignore", "pipe", "pipe"] });

  ffmpeg.stderr.on("data", (data) => {
    const msg = data.toString();
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

// Server-side segment cleanup
setInterval(() => {
  const dirs = ABR ? VARIANTS.map(v => path.join(HLS_DIR, v.name)) : [HLS_DIR];
  for (const dir of dirs) {
    const segments = fs.readdirSync(dir)
      .filter(f => f.endsWith(".ts"))
      .sort();
    if (segments.length > MAX_SEGMENTS) {
      const toDelete = segments
        .slice(0, segments.length - MAX_SEGMENTS)
        .filter(seg => !activeCaptures.has(seg));
      for (const seg of toDelete) {
        try { fs.unlinkSync(path.join(dir, seg)); } catch {}
      }
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
  if (ABR) console.log("  Adaptive bitrate: 720p / 480p / 360p");
  if (PASSWORD) console.log(`  Password: ${PASSWORD}`);
  console.log(`  Camera device: ${CAMERA}\n`);
});

// Cleanup on exit
function cleanup() {
  ffmpegProcess.kill("SIGTERM");
  process.exit();
}
process.on("SIGINT", cleanup);
process.on("SIGTERM", cleanup);
