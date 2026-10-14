import assert from "node:assert/strict";
import { describe, it } from "node:test";
import type { AuditEntry } from "./audit.js";
import { runGated, type GatedSpec } from "./gate.js";
import type { GateResult } from "./types.js";

type Entry = Omit<AuditEntry, "ts">;

const approved: GateResult = { approved: true, reason: "ok", checks: [{ name: "halt", passed: true }] };
const rejected: GateResult = { approved: false, reason: "kill switch", checks: [{ name: "halt", passed: false }] };

interface Harness {
  spec: GatedSpec;
  entries: Entry[];
  calls: string[];
  submits: () => number;
}

/**
 * Builds a spec with fakes. `failAuditOn` makes the fake audit throw for the
 * given result values (e.g. ["submitting"]).
 */
function harness(opts: {
  check?: () => GateResult | Promise<GateResult>;
  submit?: () => Promise<unknown>;
  failAuditOn?: AuditEntry["result"][];
} = {}): Harness {
  const entries: Entry[] = [];
  const calls: string[] = [];
  let submitCount = 0;
  const spec: GatedSpec = {
    tool: "place_order",
    request: { symbol: "BTCUSDT" },
    check: opts.check ?? (() => approved),
    submit: async () => {
      submitCount++;
      calls.push("submit");
      return opts.submit ? opts.submit() : { orderId: "abc" };
    },
    audit: (entry) => {
      calls.push(`audit:${entry.result}`);
      if (opts.failAuditOn?.includes(entry.result)) throw new Error("ENOSPC: disk full");
      entries.push(entry);
    },
    warn: () => {},
    messages: {
      checkError: (m) => `Gate error while checking order: ${m}`,
      rejected: (r) => `REJECTED (${r}). Do not retry this action with different numbers.`,
      success: (resp) => `APPROVED and submitted. ${JSON.stringify(resp)}`,
      failure: (m) => `Approved by the gate but the exchange rejected it: ${m}`,
    },
  };
  return { spec, entries, calls, submits: () => submitCount };
}

const textOf = (r: { content: { text: string }[] }) => r.content.map((c) => c.text).join("\n");

describe("runGated", () => {
  it("approved path writes 'submitting' then 'approved', submitting once", async () => {
    const h = harness();
    const res = await runGated(h.spec);
    assert.deepEqual(h.calls, ["audit:submitting", "submit", "audit:approved"]);
    assert.equal(h.submits(), 1);
    assert.equal(h.entries[1].result, "approved");
    assert.deepEqual(h.entries[1].exchange_response, { orderId: "abc" });
    assert.deepEqual(h.entries[0].checks, approved.checks);
    assert.equal(res.isError, undefined);
    assert.match(textOf(res), /^APPROVED and submitted\. \{"orderId":"abc"\}$/);
  });

  it("refuses without calling the exchange if the 'submitting' audit write fails", async () => {
    const h = harness({ failAuditOn: ["submitting"] });
    const res = await runGated(h.spec);
    assert.equal(h.submits(), 0);
    assert.equal(res.isError, true);
    assert.match(textOf(res), /could not write the audit log/);
    assert.match(textOf(res), /nothing was sent to the exchange/);
  });

  it("risk-reducing actions still go through if the 'submitting' audit write fails", async () => {
    const h = harness({ failAuditOn: ["submitting"] });
    const res = await runGated({ ...h.spec, riskReducing: true });
    assert.equal(h.submits(), 1);
    assert.deepEqual(h.calls, ["audit:submitting", "submit", "audit:approved"]);
    assert.equal(res.isError, undefined);
  });

  it("risk-reducing actions are still blocked by a rejected check", async () => {
    const h = harness({ check: () => rejected });
    await runGated({ ...h.spec, riskReducing: true });
    assert.equal(h.submits(), 0);
  });

  it("records 'error' and returns isError when the exchange call throws", async () => {
    const h = harness({
      submit: async () => {
        throw new Error("insufficient margin");
      },
    });
    const res = await runGated(h.spec);
    assert.deepEqual(h.calls, ["audit:submitting", "submit", "audit:error"]);
    assert.equal(h.entries[1].reason, "insufficient margin");
    assert.equal(res.isError, true);
    assert.match(textOf(res), /exchange rejected it: insufficient margin/);
  });

  it("tells the truth when the final audit write fails after a successful submit", async () => {
    const h = harness({ failAuditOn: ["approved"] });
    const res = await runGated(h.spec);
    assert.equal(h.submits(), 1);
    const t = textOf(res);
    assert.match(t, /APPROVED and submitted\. \{"orderId":"abc"\}/);
    assert.match(t, /exchange accepted this action/);
    assert.match(t, /audit log write failed/);
    assert.doesNotMatch(t, /rejected/i);
    assert.notEqual(res.isError, true);
  });

  it("rejected check: never submits, writes 'rejected', keeps the do-not-retry text", async () => {
    const h = harness({ check: () => rejected });
    const res = await runGated(h.spec);
    assert.equal(h.submits(), 0);
    assert.deepEqual(h.calls, ["audit:rejected"]);
    assert.equal(h.entries[0].reason, "kill switch");
    assert.deepEqual(h.entries[0].checks, rejected.checks);
    assert.equal(textOf(res), "REJECTED (kill switch). Do not retry this action with different numbers.");
    assert.equal(res.isError, undefined);
  });

  it("check throwing: never submits, writes 'error', returns isError", async () => {
    const h = harness({
      check: async () => {
        throw new Error("equity unavailable");
      },
    });
    const res = await runGated(h.spec);
    assert.equal(h.submits(), 0);
    assert.deepEqual(h.calls, ["audit:error"]);
    assert.deepEqual(h.entries[0].checks, []);
    assert.equal(res.isError, true);
    assert.equal(textOf(res), "Gate error while checking order: equity unavailable");
  });

  it("audit throwing on a rejection still returns the rejection", async () => {
    const h = harness({ check: () => rejected, failAuditOn: ["rejected"] });
    const res = await runGated(h.spec);
    assert.equal(h.submits(), 0);
    assert.equal(textOf(res), "REJECTED (kill switch). Do not retry this action with different numbers.");
  });

  it("audit throwing on a check error still returns the check error", async () => {
    const h = harness({
      check: () => {
        throw new Error("boom");
      },
      failAuditOn: ["error"],
    });
    const res = await runGated(h.spec);
    assert.equal(h.submits(), 0);
    assert.equal(res.isError, true);
    assert.equal(textOf(res), "Gate error while checking order: boom");
  });

  it("audit throwing on an exchange error still returns the exchange error", async () => {
    const h = harness({
      submit: async () => {
        throw new Error("timeout");
      },
      failAuditOn: ["error"],
    });
    const res = await runGated(h.spec);
    assert.equal(h.submits(), 1);
    assert.equal(res.isError, true);
    assert.match(textOf(res), /timeout/);
  });
});
