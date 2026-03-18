#!/usr/bin/env node
/**
 * OllieCam Bark/Whine Detector
 *
 * Standalone process that captures audio from the Mac mic via ffmpeg,
 * performs FFT-based bark/whine detection, and reports events to the
 * OllieCam server via POST /bark.
 *
 * Usage:
 *   node detector.js
 *
 * Environment variables:
 *   MIC        - AVFoundation audio device index (default: "default")
 *   SERVER_URL - OllieCam server URL (default: "http://localhost:3000")
 *   PASSWORD   - Server password if auth is enabled (default: "")
 */

const { spawn } = require("child_process");

const MIC = process.env.MIC || "default";
const SERVER_URL = (process.env.SERVER_URL || "http://localhost:3000").replace(/\/$/, "");
const PASSWORD = process.env.PASSWORD || "";

// ============================================================
// Audio analysis constants (match web client exactly)
// ============================================================

const SAMPLE_RATE = 44100;
const FFT_SIZE = 2048;
const ANALYSIS_INTERVAL_MS = 100;
const SAMPLES_PER_ANALYSIS = Math.floor(SAMPLE_RATE * ANALYSIS_INTERVAL_MS / 1000);

// Bark: 500-3000 Hz, loud short bursts
const BARK_LOW_HZ = 500;
const BARK_HIGH_HZ = 3000;
const BARK_SPIKE_THRESHOLD = 15;     // dB above baseline
const BARK_ABSOLUTE_THRESHOLD = -45; // dB
const BARK_COOLDOWN_MS = 3000;

// Whine: 300-5000 Hz, sustained tonal
const WHINE_LOW_HZ = 300;
const WHINE_HIGH_HZ = 5000;
const WHINE_SPIKE_THRESHOLD = 8;     // dB above baseline
const WHINE_ABSOLUTE_THRESHOLD = -50; // dB
const WHINE_SUSTAINED_FRAMES = 15;   // ~1.5s at 100ms intervals
const WHINE_COOLDOWN_MS = 5000;

const BASELINE_WINDOW = 50; // ~5s of history

// Frequency bin resolution
const BIN_HZ = SAMPLE_RATE / FFT_SIZE;
const BARK_LO_BIN = Math.floor(BARK_LOW_HZ / BIN_HZ);
const BARK_HI_BIN = Math.ceil(BARK_HIGH_HZ / BIN_HZ);
const WHINE_LO_BIN = Math.floor(WHINE_LOW_HZ / BIN_HZ);
const WHINE_HI_BIN = Math.ceil(WHINE_HIGH_HZ / BIN_HZ);

// Hanning window (precomputed)
const hanningWindow = new Float32Array(FFT_SIZE);
for (let i = 0; i < FFT_SIZE; i++) {
  hanningWindow[i] = 0.5 * (1 - Math.cos(2 * Math.PI * i / (FFT_SIZE - 1)));
}

// ============================================================
// FFT (radix-2 Cooley-Tukey)
// ============================================================

function fft(re, im) {
  const n = re.length;
  if (n <= 1) return;

  // Bit-reversal permutation
  for (let i = 1, j = 0; i < n; i++) {
    let bit = n >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) {
      [re[i], re[j]] = [re[j], re[i]];
      [im[i], im[j]] = [im[j], im[i]];
    }
  }

  // Butterfly
  for (let len = 2; len <= n; len *= 2) {
    const halfLen = len / 2;
    const angle = -2 * Math.PI / len;
    const wRe = Math.cos(angle);
    const wIm = Math.sin(angle);
    for (let i = 0; i < n; i += len) {
      let curRe = 1, curIm = 0;
      for (let j = 0; j < halfLen; j++) {
        const tRe = curRe * re[i + j + halfLen] - curIm * im[i + j + halfLen];
        const tIm = curRe * im[i + j + halfLen] + curIm * re[i + j + halfLen];
        re[i + j + halfLen] = re[i + j] - tRe;
        im[i + j + halfLen] = im[i + j] - tIm;
        re[i + j] += tRe;
        im[i + j] += tIm;
        const newCurRe = curRe * wRe - curIm * wIm;
        curIm = curRe * wIm + curIm * wRe;
        curRe = newCurRe;
      }
    }
  }
}

// Noise isolation: spectral contrast thresholds
// A bark has energy concentrated in the bark band; music spreads energy everywhere.
// Spectral contrast = bark band energy - energy outside bark band.
// High contrast → bark. Low contrast → music/noise.
const BARK_SPECTRAL_CONTRAST_MIN = 6;   // dB: bark band must exceed non-bark by this much
const WHINE_SPECTRAL_CONTRAST_MIN = 4;  // dB: whine band must exceed non-whine by this much

// Onset sharpness: barks rise fast, music changes gradually.
// Track frame-to-frame energy delta; require sharp rise for bark.
const BARK_ONSET_THRESHOLD = 10;  // dB rise from previous frame in bark band
const ONSET_HISTORY = 3;          // frames to look back for onset

// ============================================================
// Detection state
// ============================================================

const audioBuffer = new Float32Array(FFT_SIZE);
let audioBufferPos = 0;
let sampleCounter = 0;
let bufferFilled = false;
let frameCount = 0; // warmup counter — no detections until baseline is full

const baselineHistory = [];
const barkEnergyHistory = [];   // recent bark band energy for onset detection
const whineEnergyHistory = [];  // recent whine band energy
let whineFrames = 0;
let lastBarkDetect = 0;
let lastWhineDetect = 0;

function meanEnergy(dbArr, from, to) {
  let sum = 0;
  for (let i = from; i <= to; i++) sum += dbArr[i];
  return sum / (to - from + 1);
}

// Energy of bins OUTSIDE a given range (for spectral contrast)
function meanEnergyOutside(dbArr, excludeFrom, excludeTo, halfSize) {
  let sum = 0;
  let count = 0;
  for (let i = 0; i < halfSize; i++) {
    if (i < excludeFrom || i > excludeTo) {
      sum += dbArr[i];
      count++;
    }
  }
  return count > 0 ? sum / count : -100;
}

function analyzeFrame() {
  const halfSize = FFT_SIZE / 2;

  // Apply Hanning window + FFT
  const re = new Float64Array(FFT_SIZE);
  const im = new Float64Array(FFT_SIZE);
  for (let i = 0; i < FFT_SIZE; i++) {
    re[i] = audioBuffer[(audioBufferPos + i) % FFT_SIZE] * hanningWindow[i];
  }
  fft(re, im);

  // Magnitude → dB
  const db = new Float64Array(halfSize);
  for (let i = 0; i < halfSize; i++) {
    db[i] = 10 * Math.log10(re[i] * re[i] + im[i] * im[i] + 1e-10);
  }

  // Band energies
  const barkHiBin = Math.min(BARK_HI_BIN, halfSize - 1);
  const whineHiBin = Math.min(WHINE_HI_BIN, halfSize - 1);
  const barkE = meanEnergy(db, BARK_LO_BIN, barkHiBin);
  const whineE = meanEnergy(db, WHINE_LO_BIN, whineHiBin);
  const totalE = meanEnergy(db, 0, halfSize - 1);

  // Spectral contrast: how much more energy is in the target band vs the rest
  const nonBarkE = meanEnergyOutside(db, BARK_LO_BIN, barkHiBin, halfSize);
  const nonWhineE = meanEnergyOutside(db, WHINE_LO_BIN, whineHiBin, halfSize);
  const barkContrast = barkE - nonBarkE;
  const whineContrast = whineE - nonWhineE;

  // Track energy history for onset detection
  barkEnergyHistory.push(barkE);
  if (barkEnergyHistory.length > ONSET_HISTORY + 1) barkEnergyHistory.shift();
  whineEnergyHistory.push(whineE);
  if (whineEnergyHistory.length > ONSET_HISTORY + 1) whineEnergyHistory.shift();

  // Onset sharpness: max rise from any recent frame
  let barkOnset = 0;
  if (barkEnergyHistory.length > 1) {
    for (let i = 0; i < barkEnergyHistory.length - 1; i++) {
      barkOnset = Math.max(barkOnset, barkE - barkEnergyHistory[i]);
    }
  }

  // Rolling baseline
  baselineHistory.push(totalE);
  if (baselineHistory.length > BASELINE_WINDOW) baselineHistory.shift();
  const baseline = baselineHistory.reduce((a, b) => a + b, 0) / baselineHistory.length;

  const barkSpike = barkE - baseline;
  const whineSpike = whineE - baseline;
  const now = Date.now();
  frameCount++;

  // Skip detection until baseline has filled (~5s warmup)
  if (frameCount < BASELINE_WINDOW) return;

  // Bark detection: spike + absolute + spectral contrast + sharp onset + cooldown
  if (barkSpike > BARK_SPIKE_THRESHOLD &&
      barkE > BARK_ABSOLUTE_THRESHOLD &&
      barkContrast > BARK_SPECTRAL_CONTRAST_MIN &&
      barkOnset > BARK_ONSET_THRESHOLD &&
      now - lastBarkDetect > BARK_COOLDOWN_MS) {
    const confidence = Math.min(barkSpike / 30, 1.0);
    lastBarkDetect = now;
    reportDetection("bark", confidence);
  }

  // Whine detection: spike + absolute + spectral contrast + sustained + cooldown
  if (whineSpike > WHINE_SPIKE_THRESHOLD &&
      whineE > WHINE_ABSOLUTE_THRESHOLD &&
      whineContrast > WHINE_SPECTRAL_CONTRAST_MIN) {
    whineFrames++;
    if (whineFrames >= WHINE_SUSTAINED_FRAMES && now - lastWhineDetect > WHINE_COOLDOWN_MS) {
      const confidence = Math.min(whineSpike / 20, 1.0);
      lastWhineDetect = now;
      whineFrames = 0;
      reportDetection("whine", confidence);
    }
  } else {
    whineFrames = Math.max(0, whineFrames - 1);
  }
}

// ============================================================
// Server reporting
// ============================================================

async function reportDetection(type, confidence) {
  const label = type === "whine" ? "WHINE" : "BARK";
  console.log(`[${label}] confidence: ${(confidence * 100).toFixed(0)}%`);

  try {
    const headers = { "Content-Type": "application/json" };
    if (PASSWORD) {
      headers["Authorization"] = "Basic " + Buffer.from(`admin:${PASSWORD}`).toString("base64");
    }

    const res = await fetch(`${SERVER_URL}/bark`, {
      method: "POST",
      headers,
      body: JSON.stringify({ type, confidence }),
    });

    if (!res.ok) {
      console.error(`[REPORT] Server responded ${res.status}`);
    }
  } catch (err) {
    console.error(`[REPORT] Failed to reach server: ${err.message}`);
  }
}

// ============================================================
// Audio capture via ffmpeg
// ============================================================

function processAudioChunk(data) {
  const numSamples = data.length / 4;
  for (let i = 0; i < numSamples; i++) {
    audioBuffer[audioBufferPos] = data.readFloatLE(i * 4);
    audioBufferPos = (audioBufferPos + 1) % FFT_SIZE;
    if (audioBufferPos === 0) bufferFilled = true;
    sampleCounter++;

    if (sampleCounter >= SAMPLES_PER_ANALYSIS) {
      sampleCounter = 0;
      if (bufferFilled) analyzeFrame();
    }
  }
}

function startCapture() {
  if (MIC === "none") {
    console.error("Cannot run detector with MIC=none");
    process.exit(1);
  }

  const args = [
    "-f", "avfoundation",
    "-i", `:${MIC}`,
    "-f", "f32le",
    "-acodec", "pcm_f32le",
    "-ar", String(SAMPLE_RATE),
    "-ac", "1",
    "pipe:1",
  ];

  console.log(`\n  OllieCam Detector`);
  console.log(`  Mic: ${MIC}`);
  console.log(`  Server: ${SERVER_URL}`);
  console.log(`  Listening for barks and whines...\n`);

  const ffmpeg = spawn("ffmpeg", args, { stdio: ["ignore", "pipe", "pipe"] });

  ffmpeg.stdout.on("data", processAudioChunk);

  ffmpeg.stderr.on("data", (data) => {
    const msg = data.toString();
    if (msg.includes("Error") || msg.includes("error")) {
      console.error("[ffmpeg]", msg.trim());
    }
  });

  ffmpeg.on("close", (code) => {
    console.error(`Audio ffmpeg exited (code ${code}), restarting in 3s...`);
    setTimeout(startCapture, 3000);
  });

  process.on("SIGINT", () => {
    ffmpeg.kill("SIGTERM");
    process.exit();
  });
  process.on("SIGTERM", () => {
    ffmpeg.kill("SIGTERM");
    process.exit();
  });
}

startCapture();
