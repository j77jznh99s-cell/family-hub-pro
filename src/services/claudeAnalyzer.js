const fs = require('fs/promises');
const path = require('path');
const Anthropic = require('@anthropic-ai/sdk');
const { extractFrame } = require('./ffmpeg');

const MODEL = process.env.ANTHROPIC_MODEL || 'claude-sonnet-5';
const FRAMES_PER_SEGMENT = 3;

let client = null;
function getClient() {
  if (!client) {
    if (!process.env.ANTHROPIC_API_KEY) {
      throw new Error('ANTHROPIC_API_KEY is not set');
    }
    client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  }
  return client;
}

function frameTimestamps(segment) {
  const { start, end } = segment;
  const span = end - start;
  const fractions = [0.2, 0.5, 0.8];
  return fractions.slice(0, FRAMES_PER_SEGMENT).map((f) => start + span * f);
}

async function extractSegmentFrames(videoPath, segments, framesDir) {
  await fs.mkdir(framesDir, { recursive: true });
  const perSegmentFrames = [];

  for (let i = 0; i < segments.length; i++) {
    const timestamps = frameTimestamps(segments[i]);
    const files = [];
    for (let f = 0; f < timestamps.length; f++) {
      const outPath = path.join(framesDir, `seg${i}_f${f}.jpg`);
      await extractFrame(videoPath, timestamps[f], outPath);
      files.push(outPath);
    }
    perSegmentFrames.push(files);
  }
  return perSegmentFrames;
}

function extractJsonArray(text) {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const candidate = fenced ? fenced[1] : text;
  const start = candidate.indexOf('[');
  const end = candidate.lastIndexOf(']');
  if (start === -1 || end === -1 || end < start) {
    throw new Error(`Could not find a JSON array in Claude's response: ${text.slice(0, 300)}`);
  }
  return JSON.parse(candidate.slice(start, end + 1));
}

const SYSTEM_PROMPT = `You are a video producer helping select the best short-form clips from a longer video (podcast, webinar, or talk).
You will be shown a few sample frames from each candidate segment, in order, along with its start/end time in the source video.
You cannot hear the audio, so judge purely on what's visually suggested: facial expressions, gestures, on-screen text/slides, scene changes, and general energy.
For each segment, decide how likely it is to make a compelling standalone short clip (a strong visual hook, a moment of reaction, a slide with a clear takeaway, etc).
Respond with ONLY a JSON array, one object per segment, in the same order they were given, with this shape:
[{"index": 0, "title": "short punchy title", "description": "one sentence on why this moment stands out", "score": 0-10}]
No prose outside the JSON array.`;

async function analyzeSegments(videoPath, segments, framesDir) {
  if (segments.length === 0) return [];

  const perSegmentFrames = await extractSegmentFrames(videoPath, segments, framesDir);

  const content = [];
  for (let i = 0; i < segments.length; i++) {
    const { start, end } = segments[i];
    content.push({
      type: 'text',
      text: `Segment ${i}: ${start.toFixed(1)}s - ${end.toFixed(1)}s (${(end - start).toFixed(1)}s long)`,
    });
    for (const framePath of perSegmentFrames[i]) {
      const base64 = await fs.readFile(framePath, { encoding: 'base64' });
      content.push({
        type: 'image',
        source: { type: 'base64', media_type: 'image/jpeg', data: base64 },
      });
    }
  }
  content.push({
    type: 'text',
    text: `There are ${segments.length} segments total (indices 0-${segments.length - 1}). Return the JSON array now.`,
  });

  const anthropic = getClient();
  const response = await anthropic.messages.create({
    model: MODEL,
    max_tokens: 2048,
    system: SYSTEM_PROMPT,
    messages: [{ role: 'user', content }],
  });

  const text = response.content
    .filter((block) => block.type === 'text')
    .map((block) => block.text)
    .join('\n');

  const results = extractJsonArray(text);

  return segments.map((segment, i) => {
    const match = results.find((r) => r.index === i) || {};
    return {
      ...segment,
      title: match.title || `Clip ${i + 1}`,
      description: match.description || '',
      score: typeof match.score === 'number' ? match.score : 0,
      thumbnailPath: perSegmentFrames[i][1] || perSegmentFrames[i][0] || null,
    };
  });
}

module.exports = { analyzeSegments, extractJsonArray, MODEL };
