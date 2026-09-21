#!/usr/bin/env node
// Long-running process (start with e.g. `node scripts/telegram-commands.js`
// under systemd/pm2/tmux — it is NOT a cron job) that long-polls Telegram
// for /status, /halt, /resume, /close <symbol>, and /why commands.
//
// /close spawns the risk-gate MCP server as a subprocess and calls its
// close_position tool over stdio, exactly like Codex would. This keeps
// trading credentials confined to the risk gate: this script never talks
// to Bybit's private write endpoints directly, and only needs a read-only
// key for reporting on /status.
import fs from "node:fs";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { getClosedPnlToday, getEquityUsdt, getOpenPositions } from "./lib/bybit.js";
import { getUpdates, isAuthorizedChat, sendMessage } from "./lib/telegram.js";
import {
  DECISION_FILE,
  HALT_FILE,
  RISK_GATE_ENTRY,
  STATE_DIR,
  TELEGRAM_OFFSET_FILE,
} from "./lib/paths.js";

function loadOffset() {
  try {
    return JSON.parse(fs.readFileSync(TELEGRAM_OFFSET_FILE, "utf8")).offset;
  } catch {
    return undefined;
  }
}

function saveOffset(offset) {
  fs.mkdirSync(STATE_DIR, { recursive: true });
  fs.writeFileSync(TELEGRAM_OFFSET_FILE, JSON.stringify({ offset }));
}

async function callGate(tool, args) {
  const transport = new StdioClientTransport({
    command: "node",
    args: [RISK_GATE_ENTRY],
    env: process.env,
  });
  const client = new Client({ name: "telegram-commands", version: "1.0.0" });
  await client.connect(transport);
  try {
    return await client.callTool({ name: tool, arguments: args });
  } finally {
    await client.close();
  }
}

async function handleStatus() {
  const [equity, positions, dailyPnl] = await Promise.all([
    getEquityUsdt(),
    getOpenPositions(),
    getClosedPnlToday(),
  ]);
  const decision = JSON.parse(fs.readFileSync(DECISION_FILE, "utf8"));
  const halted = fs.existsSync(HALT_FILE);

  const positionLines = positions.length
    ? positions
        .map(
          (p) =>
            `  ${p.symbol} ${p.side} size ${p.size} @ ${p.entryPrice} (PnL ${p.unrealisedPnl})`
        )
        .join("\n")
    : "  none";

  return [
    `Trading: ${halted ? "HALTED" : "active"}`,
    `Equity: ${equity} USDT`,
    `Realized PnL today: ${dailyPnl} USDT`,
    `Open positions:\n${positionLines}`,
    `Last decision: ${decision.action} ${decision.symbol ?? ""} (${decision.ts ?? "never"})`,
  ].join("\n");
}

async function handleHalt() {
  fs.writeFileSync(HALT_FILE, `halted via Telegram at ${new Date().toISOString()}\n`);
  return "Trading halted. The risk gate will reject every write, including closures, until /resume.";
}

async function handleResume() {
  if (fs.existsSync(HALT_FILE)) fs.rmSync(HALT_FILE);
  return "Trading resumed.";
}

async function handleClose(symbol) {
  if (!symbol) return "Usage: /close SYMBOL (e.g. /close BTCUSDT)";
  const result = await callGate("close_position", { symbol });
  const text = result.content?.map((c) => c.text).join(" ") ?? JSON.stringify(result);
  return `close_position(${symbol}): ${text}`;
}

async function handleWhy() {
  const decision = JSON.parse(fs.readFileSync(DECISION_FILE, "utf8"));
  return `[${decision.ts ?? "never"}] ${decision.symbol ?? "-"} ${decision.action}: ${decision.reasoning}`;
}

async function handleCommand(text) {
  const [command, ...rest] = text.trim().split(/\s+/);
  switch (command) {
    case "/status":
      return handleStatus();
    case "/halt":
      return handleHalt();
    case "/resume":
      return handleResume();
    case "/close":
      return handleClose(rest[0]);
    case "/why":
      return handleWhy();
    default:
      return null; // unrecognized text, ignore
  }
}

async function pollOnce(offset) {
  const updates = await getUpdates(offset, 30);
  let nextOffset = offset;

  for (const update of updates) {
    nextOffset = update.update_id + 1;

    const text = update.message?.text;
    if (!text || !text.startsWith("/")) continue;

    if (!isAuthorizedChat(update)) {
      console.warn(`Ignoring command from unauthorized chat ${update.message?.chat?.id}`);
      continue;
    }

    try {
      const reply = await handleCommand(text);
      if (reply) await sendMessage(reply);
    } catch (err) {
      await sendMessage(`Command failed: ${err.message}`);
    }
  }

  return nextOffset;
}

async function main() {
  let offset = loadOffset();
  console.log("telegram-commands listening (Ctrl+C to stop)...");
  // eslint-disable-next-line no-constant-condition
  while (true) {
    try {
      offset = await pollOnce(offset);
      saveOffset(offset);
    } catch (err) {
      console.error(`poll error: ${err.message}`);
      await new Promise((resolve) => setTimeout(resolve, 5000));
    }
  }
}

main();
