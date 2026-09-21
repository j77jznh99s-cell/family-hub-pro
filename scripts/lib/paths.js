import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// scripts/lib -> scripts -> project root
export const BOT_DIR = path.resolve(__dirname, "..", "..");

export const HALT_FILE = path.join(BOT_DIR, "HALT_TRADING");
export const RISK_GATE_ENTRY = path.join(BOT_DIR, "risk-gate", "dist", "index.js");

export const MEMORY_DIR = path.join(BOT_DIR, "memory");
export const DECISION_FILE = path.join(MEMORY_DIR, "decision.json");
export const TRADES_FILE = path.join(MEMORY_DIR, "trades.jsonl");
export const LEARNINGS_FILE = path.join(MEMORY_DIR, "learnings.md");

export const LOG_DIR = path.join(BOT_DIR, "logs");
export const AUDIT_LOG = path.join(LOG_DIR, "audit.jsonl");
export const POSITION_LOG = path.join(LOG_DIR, "position.log");
export const FUNDING_LOG = path.join(LOG_DIR, "funding.log");

// Internal bookkeeping for these scripts only (not part of the documented
// memory/ schema, so it lives in its own hidden directory).
export const STATE_DIR = path.join(BOT_DIR, "scripts", ".state");
export const POSITION_SNAPSHOT_FILE = path.join(STATE_DIR, "positions.json");
export const TELEGRAM_OFFSET_FILE = path.join(STATE_DIR, "telegram_offset.json");

/** Pairs traded by STRATEGY.md. Keep this in sync with that file's "Pairs" line. */
export const PAIRS = ["BTCUSDT", "ETHUSDT", "SOLUSDT"];
