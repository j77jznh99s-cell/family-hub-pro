#!/usr/bin/env node
// Runs every minute via cron. Ordinary read-only monitoring: it never
// writes to the exchange, it only diffs positions against the last check
// and alerts on anything that changed (a stop-out, a take-profit hit, or a
// position that appeared without a matching cycle log). Positions are keyed
// by symbol and side, so both legs of a hedge-mode position are tracked.
import fs from "node:fs";
import { getOpenPositions } from "./lib/bybit.js";
import { diffPositions, failureStep } from "./lib/positions.js";
import { sendMessage } from "./lib/telegram.js";
import { POSITION_FAILURES_FILE, POSITION_SNAPSHOT_FILE, STATE_DIR } from "./lib/paths.js";

// Returns the raw parsed snapshot; diffPositions normalises it (including
// old plain-symbol-keyed snapshots and non-object JSON values).
function loadSnapshot() {
  try {
    return JSON.parse(fs.readFileSync(POSITION_SNAPSHOT_FILE, "utf8"));
  } catch {
    return {};
  }
}

function saveSnapshot(snapshot) {
  fs.mkdirSync(STATE_DIR, { recursive: true });
  fs.writeFileSync(POSITION_SNAPSHOT_FILE, JSON.stringify(snapshot, null, 2));
}

async function main() {
  const previous = loadSnapshot();
  // getOpenPositions throws on a malformed response, so main() rejects here
  // and the snapshot below is not overwritten with a bogus "no positions".
  const current = await getOpenPositions();
  const { alerts, snapshot } = diffPositions(previous, current);

  for (const alert of alerts) {
    console.log(alert);
    await sendMessage(`[position-check] ${alert}`);
  }

  saveSnapshot(snapshot);
}

function loadFailureCount() {
  try {
    return JSON.parse(fs.readFileSync(POSITION_FAILURES_FILE, "utf8")).count;
  } catch {
    return 0;
  }
}

// Never throws: a broken failure counter or Telegram must not mask the run's
// own result.
async function trackFailures(failed, errorMessage) {
  try {
    const { count, alert } = failureStep(loadFailureCount(), failed, errorMessage);
    fs.mkdirSync(STATE_DIR, { recursive: true });
    fs.writeFileSync(POSITION_FAILURES_FILE, JSON.stringify({ count }));
    if (alert) {
      console.log(alert);
      await sendMessage(`[position-check] ${alert}`);
    }
  } catch (err) {
    console.error(`position-check failure tracking failed: ${err.message}`);
  }
}

main()
  .then(() => trackFailures(false))
  .catch(async (err) => {
    console.error(`position-check failed: ${err.message}`);
    process.exitCode = 1;
    await trackFailures(true, err.message);
  });
