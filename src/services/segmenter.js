// Turns ffmpeg silencedetect output into candidate "speech segments", then shapes
// those into clip-length windows suitable for scoring by Claude.

const DEFAULTS = {
  mergeGapSeconds: 1.2, // silences shorter than this don't split a thought in two
  minClipSeconds: 12,
  maxClipSeconds: 90,
  targetClipSeconds: 45,
  maxCandidates: 15,
};

function invertSilences(duration, silences) {
  const speech = [];
  let cursor = 0;
  for (const { start, end } of silences) {
    if (start > cursor) speech.push({ start: cursor, end: start });
    cursor = Math.max(cursor, end);
  }
  if (cursor < duration) speech.push({ start: cursor, end: duration });
  return speech.filter((s) => s.end - s.start > 0.2);
}

function mergeCloseSegments(segments, mergeGapSeconds) {
  if (segments.length === 0) return [];
  const merged = [{ ...segments[0] }];
  for (let i = 1; i < segments.length; i++) {
    const prev = merged[merged.length - 1];
    const curr = segments[i];
    if (curr.start - prev.end <= mergeGapSeconds) {
      prev.end = curr.end;
    } else {
      merged.push({ ...curr });
    }
  }
  return merged;
}

function splitLongSegment(segment, targetClipSeconds, maxClipSeconds) {
  const length = segment.end - segment.start;
  if (length <= maxClipSeconds) return [segment];

  const chunks = Math.ceil(length / targetClipSeconds);
  const chunkLength = length / chunks;
  const result = [];
  for (let i = 0; i < chunks; i++) {
    result.push({
      start: segment.start + i * chunkLength,
      end: segment.start + (i + 1) * chunkLength,
    });
  }
  return result;
}

function pickEvenlySpaced(segments, maxCount) {
  if (segments.length <= maxCount) return segments;
  // Bias toward longer segments (more likely to contain a self-contained moment),
  // then re-sort chronologically so downstream frame extraction stays sequential.
  const byLength = [...segments].sort((a, b) => b.end - b.start - (a.end - a.start));
  const kept = byLength.slice(0, maxCount);
  return kept.sort((a, b) => a.start - b.start);
}

function buildCandidateSegments(duration, silences, overrides = {}) {
  const opts = { ...DEFAULTS, ...overrides };

  const speech = invertSilences(duration, silences);
  const merged = mergeCloseSegments(speech, opts.mergeGapSeconds);

  let shaped = merged.flatMap((seg) => splitLongSegment(seg, opts.targetClipSeconds, opts.maxClipSeconds));
  shaped = shaped.filter((seg) => seg.end - seg.start >= opts.minClipSeconds);

  if (shaped.length === 0 && duration > 0) {
    // No usable silence-based segmentation (e.g. no clear pauses) - fall back to
    // fixed-length windows across the whole video so we still have candidates.
    const windowCount = Math.max(1, Math.ceil(duration / opts.targetClipSeconds));
    for (let i = 0; i < windowCount; i++) {
      const start = i * opts.targetClipSeconds;
      const end = Math.min(duration, start + opts.targetClipSeconds);
      if (end - start >= 3) shaped.push({ start, end });
    }
  }

  return pickEvenlySpaced(shaped, opts.maxCandidates);
}

module.exports = { buildCandidateSegments, DEFAULTS };
