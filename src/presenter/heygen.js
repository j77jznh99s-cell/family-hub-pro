// Renders a script as a talking-avatar video with HeyGen.
// Endpoints/fields per HeyGen's OpenAPI spec: POST /v2/video/generate, GET
// /v1/video_status.get, auth via the X-Api-Key header. The response fields
// (data.video_id, data.status, data.video_url) are read defensively since HeyGen
// doesn't publish response schemas - errors include the raw body to make any drift obvious.
const { writeFileAtomic } = require('./fsutil');

const API_BASE = process.env.HEYGEN_API_BASE || 'https://api.heygen.com';

function heygenConfig(env = process.env) {
  return {
    apiKey: env.HEYGEN_API_KEY || '',
    // A trained video avatar ("Instant/Digital Twin", best) or a photo avatar (quick start).
    avatarId: env.HEYGEN_AVATAR_ID || '',
    talkingPhotoId: env.HEYGEN_TALKING_PHOTO_ID || '',
    avatarStyle: env.HEYGEN_AVATAR_STYLE || 'normal',
    voiceId: env.HEYGEN_VOICE_ID || '',
    // Free, watermarked renders that don't spend credits - good for a first check.
    test: env.HEYGEN_TEST === 'true',
    width: parseInt(env.PRESENTER_WIDTH || '1080', 10),
    height: parseInt(env.PRESENTER_HEIGHT || '1920', 10),
  };
}

function missingConfig(cfg) {
  const missing = [];
  if (!cfg.apiKey) missing.push('HEYGEN_API_KEY');
  if (!cfg.avatarId && !cfg.talkingPhotoId) missing.push('HEYGEN_AVATAR_ID (or HEYGEN_TALKING_PHOTO_ID)');
  if (!cfg.voiceId) missing.push('HEYGEN_VOICE_ID');
  return missing;
}

function buildGenerateBody(cfg, { script, title }) {
  const character = cfg.avatarId
    ? { type: 'avatar', avatar_id: cfg.avatarId, avatar_style: cfg.avatarStyle }
    : { type: 'talking_photo', talking_photo_id: cfg.talkingPhotoId };
  return {
    title: title || 'AI presenter video',
    test: cfg.test,
    dimension: { width: cfg.width, height: cfg.height },
    video_inputs: [
      {
        character,
        voice: { type: 'text', input_text: script, voice_id: cfg.voiceId },
      },
    ],
  };
}

async function heygenRequest(fetchImpl, cfg, method, path, body) {
  const res = await fetchImpl(`${API_BASE}${path}`, {
    method,
    headers: {
      'X-Api-Key': cfg.apiKey,
      Accept: 'application/json',
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = null;
  }
  if (!res.ok || !json || (json.error && json.error !== null)) {
    throw new Error(`HeyGen ${method} ${path} failed (${res.status}): ${text.slice(0, 500)}`);
  }
  return json;
}

async function startVideo(cfg, payload, { fetchImpl = fetch } = {}) {
  const json = await heygenRequest(fetchImpl, cfg, 'POST', '/v2/video/generate', buildGenerateBody(cfg, payload));
  const videoId = json.data?.video_id;
  if (!videoId) throw new Error(`HeyGen didn't return a video_id: ${JSON.stringify(json).slice(0, 500)}`);
  return videoId;
}

async function waitForVideo(cfg, videoId, { fetchImpl = fetch, intervalMs = 15000, timeoutMs = 30 * 60 * 1000, onStatus } = {}) {
  const started = Date.now();
  for (;;) {
    const json = await heygenRequest(
      fetchImpl,
      cfg,
      'GET',
      `/v1/video_status.get?video_id=${encodeURIComponent(videoId)}`
    );
    const data = json.data || {};
    if (onStatus) onStatus(data.status);
    if (data.status === 'completed') {
      if (!data.video_url) throw new Error('HeyGen marked the video completed but gave no video_url');
      return { videoUrl: data.video_url, thumbnailUrl: data.thumbnail_url || null, captionUrl: data.caption_url || null, duration: data.duration || null };
    }
    if (data.status === 'failed') {
      throw new Error(`HeyGen render failed: ${JSON.stringify(data.error || data).slice(0, 500)}`);
    }
    if (Date.now() - started > timeoutMs) throw new Error(`Timed out waiting for HeyGen video ${videoId}`);
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }
}

async function downloadTo(url, outPath, { fetchImpl = fetch } = {}) {
  const res = await fetchImpl(url);
  if (!res.ok) throw new Error(`Download failed (${res.status}) for ${url}`);
  // Atomic: a dropped connection mustn't leave a truncated video.mp4 that looks rendered.
  await writeFileAtomic(outPath, Buffer.from(await res.arrayBuffer()));
  return outPath;
}

module.exports = { heygenConfig, missingConfig, buildGenerateBody, startVideo, waitForVideo, downloadTo };
