import fs from "node:fs";
import { AUDIT_LOG, LOG_DIR } from "./paths.js";
import type { CheckStep } from "./types.js";

export interface AuditEntry {
  ts: string;
  tool: string;
  request: unknown;
  checks: CheckStep[];
  result: "approved" | "rejected" | "error";
  reason?: string;
  exchange_response?: unknown;
}

export function appendAudit(entry: Omit<AuditEntry, "ts">): AuditEntry {
  const full: AuditEntry = { ts: new Date().toISOString(), ...entry };
  fs.mkdirSync(LOG_DIR, { recursive: true });
  fs.appendFileSync(AUDIT_LOG, JSON.stringify(full) + "\n");
  return full;
}
