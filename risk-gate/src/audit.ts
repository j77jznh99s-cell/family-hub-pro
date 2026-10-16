import fs from "node:fs";
import { AUDIT_LOG, LOG_DIR } from "./paths.js";
import type { CheckStep } from "./types.js";

export interface AuditEntry {
  ts: string;
  tool: string;
  request: unknown;
  checks: CheckStep[];
  /**
   * "submitting" is written before an approved action is forwarded to the
   * exchange; it is always followed by "approved" or "error" unless the
   * process died mid-call (in which case check the exchange's order history).
   */
  result: "submitting" | "approved" | "rejected" | "error";
  /**
   * Links a "submitting" entry to its follow-up "approved"/"error" entry for
   * the same exchange call (one random UUID per approved runGated call).
   * Only set on those three entry kinds; "rejected" and check-error entries
   * never reach the exchange and omit it. Optional so older log lines stay valid.
   */
  attempt_id?: string;
  reason?: string;
  exchange_response?: unknown;
}

export function appendAudit(entry: Omit<AuditEntry, "ts">): AuditEntry {
  const full: AuditEntry = { ts: new Date().toISOString(), ...entry };
  fs.mkdirSync(LOG_DIR, { recursive: true });
  fs.appendFileSync(AUDIT_LOG, JSON.stringify(full) + "\n");
  return full;
}
