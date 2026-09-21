#!/usr/bin/env node
// Runs every four hours via cron. Read-only: alerts when a pair's funding
// rate crosses the threshold STRATEGY.md uses to gate entries (0.03% per
// 8h), so a human sees a heads-up between 15-minute cycles instead of only
// finding out when the model happens to check next.
import { getFundingRate } from "./lib/bybit.js";
import { sendMessage } from "./lib/telegram.js";
import { PAIRS } from "./lib/paths.js";

const THRESHOLD = 0.0003; // 0.03% per 8h, matches STRATEGY.md's entry filter

async function main() {
  const alerts = [];
  for (const symbol of PAIRS) {
    const rate = await getFundingRate(symbol);
    if (rate === null) continue;
    if (Math.abs(rate) > THRESHOLD) {
      alerts.push(
        `${symbol} funding rate ${(rate * 100).toFixed(4)}% exceeds the ` +
          `${(THRESHOLD * 100).toFixed(2)}% entry threshold in STRATEGY.md.`
      );
    }
  }

  for (const alert of alerts) {
    console.log(alert);
    await sendMessage(`[funding-check] ${alert}`);
  }
}

main().catch((err) => {
  console.error(`funding-check failed: ${err.message}`);
  process.exitCode = 1;
});
