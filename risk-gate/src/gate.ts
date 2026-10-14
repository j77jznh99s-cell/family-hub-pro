import { appendAudit, type AuditEntry } from "./audit.js";
import type { GateResult } from "./types.js";

export type AuditFn = (entry: Omit<AuditEntry, "ts">) => unknown;

export interface ToolResult {
  [key: string]: unknown;
  content: { type: "text"; text: string }[];
  isError?: boolean;
}

/** Text the model sees for each outcome. Kept per tool so wording is unchanged. */
export interface GateMessages {
  rejected(reason: string): string;
  checkError(message: string): string;
  success(exchangeResponse: unknown): string;
  failure(message: string): string;
}

export interface GatedSpec {
  tool: string;
  request: unknown;
  /** Runs the risk checks. May throw; a throw never reaches the exchange. */
  check: () => GateResult | Promise<GateResult>;
  /** The exchange write. Only called after checks pass AND the "submitting" audit entry is on disk. */
  submit: () => Promise<unknown>;
  messages: GateMessages;
  /**
   * Risk-reducing actions (close, cancel) are blocked only by the kill switch,
   * so a failed "submitting" write warns and still lets them through.
   * Everything else fails closed.
   */
  riskReducing?: boolean;
  audit?: AuditFn;
  /** Operator-facing warnings (stderr by default; stdout is the MCP channel). */
  warn?: (message: string) => void;
}

function errMsg(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}

function text(t: string, isError = false): ToolResult {
  return isError ? { content: [{ type: "text", text: t }], isError: true } : { content: [{ type: "text", text: t }] };
}

/**
 * Shared fail-closed flow for every exchange write:
 *   check -> audit "submitting" -> submit -> audit "approved" | "error".
 * If the "submitting" entry cannot be written, nothing is sent to the exchange.
 * If the final entry cannot be written, the result still reports what the
 * exchange actually did.
 */
export async function runGated(spec: GatedSpec): Promise<ToolResult> {
  const audit: AuditFn = spec.audit ?? appendAudit;
  const warn = spec.warn ?? ((m: string) => console.error(`[risk-gate] ${m}`));
  const { tool, request, messages } = spec;

  // Best-effort audit for paths that never touch the exchange: a failed write
  // must not turn a rejection or check error into a crash.
  const auditBestEffort = (entry: Omit<AuditEntry, "ts">): void => {
    try {
      audit(entry);
    } catch (err) {
      warn(`${tool}: audit log write failed for a "${entry.result}" entry: ${errMsg(err)}`);
    }
  };

  let result: GateResult;
  try {
    result = await spec.check();
  } catch (err) {
    auditBestEffort({ tool, request, checks: [], result: "error", reason: errMsg(err) });
    return text(messages.checkError(errMsg(err)), true);
  }

  if (!result.approved) {
    auditBestEffort({ tool, request, checks: result.checks, result: "rejected", reason: result.reason });
    return text(messages.rejected(result.reason));
  }

  // Fail closed: no audit record on disk, no exchange call (except for
  // risk-reducing actions, which must never be stuck behind a full disk).
  try {
    audit({ tool, request, checks: result.checks, result: "submitting" });
  } catch (err) {
    if (spec.riskReducing) {
      warn(`${tool}: audit log write failed before submit, sending anyway (risk-reducing): ${errMsg(err)}`);
    } else {
      warn(`${tool}: refused, audit log write failed before submit: ${errMsg(err)}`);
      return text(
        `REFUSED: the gate approved this action but could not write the audit log ` +
          `(${errMsg(err)}), so nothing was sent to the exchange. ` +
          `Do not retry until the audit log is writable.`,
        true
      );
    }
  }

  let exchangeResponse: unknown;
  try {
    exchangeResponse = await spec.submit();
  } catch (err) {
    auditBestEffort({ tool, request, checks: result.checks, result: "error", reason: errMsg(err) });
    return text(messages.failure(errMsg(err)), true);
  }

  try {
    audit({ tool, request, checks: result.checks, result: "approved", exchange_response: exchangeResponse });
  } catch (err) {
    warn(`${tool}: exchange accepted the action but the follow-up audit write failed: ${errMsg(err)}`);
    return text(
      `${messages.success(exchangeResponse)} ` +
        `WARNING: the exchange accepted this action, but the follow-up audit log write failed ` +
        `(${errMsg(err)}). The "submitting" entry is on disk; the exchange response above is the record. ` +
        `Do not resubmit this action.`
    );
  }

  return text(messages.success(exchangeResponse));
}
