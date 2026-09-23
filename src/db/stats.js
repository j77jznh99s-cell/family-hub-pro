// Shared by both DB drivers so GET /api/stats has an identical shape (and number types -
// pg returns COUNT/SUM/AVG as strings) whichever driver is active.
function num(value) {
  if (value === null || value === undefined) return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function round(value, places) {
  if (value === null) return null;
  const factor = 10 ** places;
  return Math.round(value * factor) / factor;
}

function buildStats({ statusRows, totals, recent, clips }) {
  const byStatus = { uploaded: 0, processing: 0, complete: 0, failed: 0 };
  let total = 0;
  for (const row of statusRows) {
    const count = num(row.count) || 0;
    byStatus[row.status] = count;
    total += count;
  }

  const avgMs = num(totals.avg_processing_ms);
  const maxMs = num(totals.max_processing_ms);
  const finished = byStatus.complete + byStatus.failed;

  return {
    jobs: {
      total,
      byStatus,
      last24h: num(recent.last_24h) || 0,
      last7d: num(recent.last_7d) || 0,
      // Of jobs that reached a terminal state; null until one has.
      failureRate: finished ? round(byStatus.failed / finished, 4) : null,
    },
    clips: { total: num(clips) || 0 },
    processing: {
      sourceMinutesProcessed: round((num(totals.source_seconds) || 0) / 60, 2),
      avgSeconds: avgMs === null ? null : round(avgMs / 1000, 1),
      maxSeconds: maxMs === null ? null : round(maxMs / 1000, 1),
    },
  };
}

module.exports = { buildStats };
