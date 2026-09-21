// Transcript-based scoring/captions - entirely optional. When OPENAI_API_KEY is unset,
// transcribe() returns null and the pipeline falls back to its original frame-only
// behavior (see README's "honest limitation" section from Phase 1).
const fs = require('fs');
const OpenAI = require('openai');

const { OPENAI_API_KEY, OPENAI_TRANSCRIBE_MODEL } = require('../config');
const ffmpeg = require('./ffmpeg');

let client = null;
function getClient() {
  if (!client) client = new OpenAI({ apiKey: OPENAI_API_KEY });
  return client;
}

// Extracts audio from videoPath into audioPath, transcribes it, and returns
// { segments: [{start, end, text}], fullText } - or null if no API key is configured.
async function transcribe(videoPath, audioPath) {
  if (!OPENAI_API_KEY) return null;

  await ffmpeg.extractAudio(videoPath, audioPath);

  const openai = getClient();
  const response = await openai.audio.transcriptions.create({
    file: fs.createReadStream(audioPath),
    model: OPENAI_TRANSCRIBE_MODEL,
    response_format: 'verbose_json',
    timestamp_granularities: ['segment'],
  });

  const segments = (response.segments || [])
    .map((s) => ({ start: s.start, end: s.end, text: (s.text || '').trim() }))
    .filter((s) => s.text);

  return { segments, fullText: response.text || '' };
}

// Concatenates the transcript text overlapping [start, end) - used to give Claude the
// actual words spoken during a candidate segment, not just sampled frames.
function textForRange(transcript, start, end) {
  if (!transcript) return '';
  return transcript.segments
    .filter((s) => s.end > start && s.start < end)
    .map((s) => s.text)
    .join(' ')
    .trim();
}

module.exports = { transcribe, textForRange };
