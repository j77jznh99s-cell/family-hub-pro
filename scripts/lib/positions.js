// Pure helpers for position-check.js: diff the last position snapshot
// against the current open positions. Kept here so it can be unit-tested.
//
// Positions are keyed by symbol AND side, because in Bybit hedge mode an
// account can hold a Buy and a Sell position on the same symbol at once
// (/v5/position/list returns two rows, positionIdx 1 and 2). Keying by side
// also catches a one-way-mode side flip (Buy closed, Sell opened between
// two checks) as one "closed" plus one "detected" alert.
import { guessOutcome } from "./outcome.js";

const SIDES = new Set(["Buy", "Sell"]);

function isPlainObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function hasKeyFields(p) {
  return (
    isPlainObject(p) &&
    typeof p.symbol === "string" &&
    p.symbol.trim() !== "" &&
    SIDES.has(p.side)
  );
}

/** Snapshot key for a position: `${symbol}:${side}`, e.g. "BTCUSDT:Buy". */
export function positionKey(p) {
  return `${p.symbol}:${p.side}`;
}

/**
 * Normalise a loaded snapshot into the `${symbol}:${side}` keyed shape.
 * Accepts both the current format and the old plain-symbol-keyed format
 * (`{"BTCUSDT": {symbol, side, ...}}`) by re-keying every entry from its own
 * symbol and side, so the first run after the upgrade raises no false
 * alerts. A snapshot that is not a plain object (null, an array, a number)
 * becomes {}, and entries that are not objects or lack a valid symbol/side
 * are dropped.
 */
export function normaliseSnapshot(raw) {
  const snapshot = {};
  if (!isPlainObject(raw)) return snapshot;
  for (const value of Object.values(raw)) {
    if (!hasKeyFields(value)) continue;
    snapshot[positionKey(value)] = value;
  }
  return snapshot;
}

function closedAlert(prev) {
  return (
    `Position closed: ${prev.symbol} ${prev.side} — ${guessOutcome(prev)}. ` +
    `Last unrealised PnL ${prev.unrealisedPnl}.`
  );
}

function detectedAlert(p) {
  return (
    `Position detected: ${p.symbol} ${p.side} size ${p.size} @ ${p.entryPrice}, ` +
    `stop ${p.stopLoss ?? "none"}, take profit ${p.takeProfit ?? "none"}.`
  );
}

/**
 * Diff a previous snapshot (either format; it is normalised here) against
 * the current open positions (the output of parsePositions).
 * Returns { alerts, snapshot }: the alert texts, closed ones first, and the
 * new `${symbol}:${side}` keyed snapshot to save.
 */
export function diffPositions(previousSnapshot, currentPositions) {
  const previous = normaliseSnapshot(previousSnapshot);
  const snapshot = {};
  for (const p of currentPositions) {
    snapshot[positionKey(p)] = p;
  }

  const alerts = [];
  for (const [key, prev] of Object.entries(previous)) {
    if (!Object.hasOwn(snapshot, key)) alerts.push(closedAlert(prev));
  }
  for (const [key, p] of Object.entries(snapshot)) {
    if (!Object.hasOwn(previous, key)) alerts.push(detectedAlert(p));
  }

  return { alerts, snapshot };
}

/** Consecutive failed runs (one per minute under cron) before the owner is told. */
export const FAILURE_ALERT_AFTER = 3;

/**
 * Track consecutive position-check failures so a long outage or bad data
 * sends ONE Telegram alert instead of none (cron only logs) or one a minute.
 * Returns { count, alert }: the new count to save and the text to send, or
 * null. Alerts once when the count reaches FAILURE_ALERT_AFTER, and once
 * more when a run succeeds after that.
 */
export function failureStep(previousCount, failed, errorMessage = "") {
  const prev = Number.isInteger(previousCount) && previousCount > 0 ? previousCount : 0;
  if (!failed) {
    const alert =
      prev >= FAILURE_ALERT_AFTER
        ? `position-check is working again after ${prev} failed runs. Check positions: changes during the outage were not alerted.`
        : null;
    return { count: 0, alert };
  }
  const count = prev + 1;
  const alert =
    count === FAILURE_ALERT_AFTER
      ? `position-check has failed ${count} runs in a row, so positions are NOT being monitored. Last error: ${errorMessage}`
      : null;
  return { count, alert };
}
