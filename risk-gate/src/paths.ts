import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/** risk-gate/dist -> risk-gate */
export const RISK_GATE_DIR = path.resolve(__dirname, "..");
/** risk-gate -> project root, resolved from the running file's own location
 *  so the gate finds HALT_TRADING and logs/ regardless of the process cwd
 *  configured for it in ~/.codex/config.toml. */
export const BOT_DIR = path.resolve(RISK_GATE_DIR, "..");

export const HALT_FILE = path.join(BOT_DIR, "HALT_TRADING");
export const LOG_DIR = path.join(BOT_DIR, "logs");
export const AUDIT_LOG = path.join(LOG_DIR, "audit.jsonl");
