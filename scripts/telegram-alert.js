#!/usr/bin/env node
// Send a Telegram alert. Usage: node scripts/telegram-alert.js "message text"
// Used by the trading cycle prompt to report each cycle's outcome, and by
// position-check.js / funding-check.js for standalone alerts.
import { sendMessage } from "./lib/telegram.js";

async function main() {
  const text = process.argv.slice(2).join(" ").trim();
  if (!text) {
    console.error('Usage: node scripts/telegram-alert.js "message text"');
    process.exitCode = 1;
    return;
  }
  await sendMessage(text);
}

main().catch((err) => {
  console.error(`telegram-alert failed: ${err.message}`);
  process.exitCode = 1;
});
