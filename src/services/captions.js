// Builds an SRT subtitle file from transcript segments, re-timed so 0 is the first
// frame of the exported clip (the transcript's timestamps are relative to the full
// source video, but ffmpeg burns captions into a clip that starts at 0).
function formatSrtTimestamp(seconds) {
  const ms = Math.max(0, Math.round(seconds * 1000));
  const hh = Math.floor(ms / 3600000);
  const mm = Math.floor((ms % 3600000) / 60000);
  const ss = Math.floor((ms % 60000) / 1000);
  const mmm = ms % 1000;
  return `${String(hh).padStart(2, '0')}:${String(mm).padStart(2, '0')}:${String(ss).padStart(2, '0')},${String(mmm).padStart(3, '0')}`;
}

// Returns an SRT-formatted string, or null if the transcript has nothing to say during
// this clip's time range.
function buildSrt(transcript, clipStart, clipEnd) {
  if (!transcript) return null;

  const overlapping = transcript.segments
    .filter((s) => s.end > clipStart && s.start < clipEnd)
    .map((s) => ({
      start: Math.max(0, s.start - clipStart),
      end: Math.min(clipEnd - clipStart, s.end - clipStart),
      text: s.text,
    }))
    .filter((s) => s.end > s.start && s.text);

  if (overlapping.length === 0) return null;

  return (
    overlapping
      .map(
        (s, i) =>
          `${i + 1}\n${formatSrtTimestamp(s.start)} --> ${formatSrtTimestamp(s.end)}\n${s.text}\n`
      )
      .join('\n') + '\n'
  );
}

module.exports = { buildSrt };
