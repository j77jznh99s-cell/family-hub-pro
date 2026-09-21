#!/usr/bin/env node
// Runs every minute via cron. Ordinary read-only monitoring: it never
// writes to the exchange, it only diffs positions against the last check
// and alerts on anything that changed (a stop-out, a take-profit hit, or a
// position that appeared without a matching cycle log).
import fs from "node:fs";
import { getOpenPositions } from "./lib/bybit.js";
import { sendMessage } from "./lib/telegram.js";
import { POSITION_SNAPSHOT_FILE, STATE_DIR } from "./lib/paths.js";

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

function guessOutcome(prev) {
  if (prev.stopLoss !== null && prev.markPrice !== undefined) {
    const nearStop = Math.abs(prev.markPrice - prev.stopLoss) / prev.stopLoss < 0.005;
    if (nearStop) return "likely stop-out";
  }
  if (prev.takeProfit !== null && prev.markPrice !== undefined) {
    const nearTp = Math.abs(prev.markPrice - prev.takeProfit) / prev.takeProfit < 0.005;
    if (nearTp) return "likely take-profit";
  }
  return "closed (reason unclear, check logs/audit.jsonl and Bybit order history)";
}

async function main() {
  const previous = loadSnapshot();
  const current = await getOpenPositions();
  const currentBySymbol = Object.fromEntries(current.map((p) => [p.symbol, p]));

  const alerts = [];

  for (const [symbol, prev] of Object.entries(previous)) {
    if (!currentBySymbol[symbol]) {
      alerts.push(`Position closed: ${symbol} — ${guessOutcome(prev)}. Last unrealised PnL ${prev.unrealisedPnl}.`);
    }
  }

  for (const p of current) {
    if (!previous[p.symbol]) {
      alerts.push(
        `Position detected: ${p.symbol} ${p.side} size ${p.size} @ ${p.entryPrice}, ` +
          `stop ${p.stopLoss ?? "none"}, take profit ${p.takeProfit ?? "none"}.`
      );
    }
  }

  for (const alert of alerts) {
    console.log(alert);
    await sendMessage(`[position-check] ${alert}`);
  }

  saveSnapshot(currentBySymbol);
}

main().catch((err) => {
  console.error(`position-check failed: ${err.message}`);
  process.exitCode = 1;
});
