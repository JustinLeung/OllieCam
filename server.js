const express = require("express");
const { spawn } = require("child_process");
const path = require("path");
const fs = require("fs");

const PORT = process.env.PORT || 3000;
const CAMERA = process.env.CAMERA || "0";   // AVFoundation video device index
const MIC = process.env.MIC || "default";    // AVFoundation audio device index (or "none" to disable)
const PASSWORD = process.env.PASSWORD || ""; // Set to require basic auth
const HLS_DIR = path.join(__dirname, "stream");

// Ensure stream directory exists
if (!fs.existsSync(HLS_DIR)) fs.mkdirSync(HLS_DIR);

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

app.post("/bark", (req, res) => {
  const type = req.body.type === "whine" ? "whine" : "bark";
  const event = {
    type,
    confidence: req.body.confidence,
    timestamp: new Date().toISOString(),
  };
  const label = type === "whine" ? "WHINE" : "BARK";
  console.log(`[${label}] ${event.timestamp} (confidence: ${(event.confidence * 100).toFixed(0)}%)`);
  for (const client of sseClients) {
    client.write(`data: ${JSON.stringify(event)}\n\n`);
  }
  res.json({ ok: true });
});

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
    "-hls_flags", "delete_segments+append_list",
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
