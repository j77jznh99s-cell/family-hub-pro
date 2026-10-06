// Pure helper for position-check.js: guess why a position disappeared,
// from the last snapshot of it. Kept here so it can be unit-tested.

const NEAR_FRACTION = 0.005; // within 0.5% of the level

function isUsablePrice(value) {
  return typeof value === "number" && Number.isFinite(value) && value > 0;
}

function isNear(price, level) {
  return Math.abs(price - level) / level < NEAR_FRACTION;
}

/**
 * Guess the outcome for a previously-snapshotted position that is now gone.
 * A stop or take profit that is null, 0, missing or non-finite (e.g. from an
 * older snapshot written before the client parsed "0" as "none") is ignored
 * rather than divided by.
 */
export function guessOutcome(prev) {
  const mark = prev?.markPrice;
  if (isUsablePrice(mark)) {
    if (isUsablePrice(prev.stopLoss) && isNear(mark, prev.stopLoss)) {
      return "likely stop-out";
    }
    if (isUsablePrice(prev.takeProfit) && isNear(mark, prev.takeProfit)) {
      return "likely take-profit";
    }
  }
  return "closed (reason unclear, check logs/audit.jsonl and Bybit order history)";
}
