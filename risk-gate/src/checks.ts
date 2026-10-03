import fs from "node:fs";
import { HALT_FILE } from "./paths.js";
import type { BybitClient, CheckStep, GateResult, OrderRequest } from "./types.js";

const LEVERAGE_CAP: Record<string, number> = {
  BTCUSDT: 10,
  ETHUSDT: 5,
  SOLUSDT: 5,
};
const DEFAULT_LEVERAGE_CAP = 5;

const DAILY_LOSS_CAP_PCT = 0.05;
const NOTIONAL_CAP_PCT = 0.3;
const PRICE_SANITY_PCT = 0.02;
const MAX_OPEN_POSITIONS = 3;

export function leverageCapFor(symbol: string): number {
  return LEVERAGE_CAP[symbol] ?? DEFAULT_LEVERAGE_CAP;
}

function halted(): boolean {
  return fs.existsSync(HALT_FILE);
}

function pass(checks: CheckStep[]): GateResult {
  return { approved: true, reason: "ok", checks };
}

function reject(reason: string, checks: CheckStep[]): GateResult {
  return { approved: false, reason, checks };
}

/** True only for a real number above zero (rejects 0, negatives, NaN, Infinity). */
function isPositiveFinite(n: unknown): boolean {
  return typeof n === "number" && Number.isFinite(n) && n > 0;
}

/** True only for a finite leverage of at least 1x. */
function isValidLeverage(n: unknown): boolean {
  return typeof n === "number" && Number.isFinite(n) && n >= 1;
}

/** Fail closed on garbage inputs or exchange data (e.g. Number("") === 0).
 *  Only pushed on failure, so an approved order's checks are unchanged. */
function rejectInput(field: string, value: unknown, checks: CheckStep[]): GateResult {
  checks.push({ name: "input_sanity", passed: false, detail: { field, value } });
  return reject("input_sanity", checks);
}

/**
 * Checks that gate every write, including closures and cancels: the kill
 * switch is a full stop, not just an entry filter.
 */
export function checkHalt(): CheckStep {
  return { name: "kill_switch", passed: !halted() };
}

/**
 * Full pipeline for a new entry (place_order). Runs in the fixed order the
 * strategy contract requires; the model never sees which check tripped
 * before choosing not to retry, it only sees the final rejection reason.
 */
export async function checkOrder(
  req: OrderRequest,
  bybit: BybitClient
): Promise<GateResult> {
  const checks: CheckStep[] = [];

  const kill = checkHalt();
  checks.push(kill);
  if (!kill.passed) {
    return reject("kill_switch", checks);
  }

  // input_sanity: checkOrder is exported, so re-validate even though zod
  // checks these at the MCP boundary.
  if (!isPositiveFinite(req.qty)) {
    return rejectInput("qty", req.qty, checks);
  }
  if (req.price !== undefined && !isPositiveFinite(req.price)) {
    return rejectInput("price", req.price, checks);
  }

  const equity = await bybit.equityUsdt();
  if (!isPositiveFinite(equity)) {
    return rejectInput("equity", equity, checks);
  }
  const todayPnl = await bybit.pnlSinceMidnightUtc();
  if (typeof todayPnl !== "number" || !Number.isFinite(todayPnl)) {
    return rejectInput("todayPnl", todayPnl, checks);
  }
  const dailyLossOk = todayPnl >= -DAILY_LOSS_CAP_PCT * equity;
  checks.push({
    name: "daily_loss_cap",
    passed: dailyLossOk,
    detail: { equity, todayPnl, capPct: DAILY_LOSS_CAP_PCT },
  });
  if (!dailyLossOk) {
    return reject("daily_loss_cap", checks);
  }

  const mark = await bybit.markPrice(req.symbol);
  if (!isPositiveFinite(mark)) {
    return rejectInput("mark", mark, checks);
  }
  const notional = req.qty * mark;
  const notionalOk = notional <= NOTIONAL_CAP_PCT * equity;
  checks.push({
    name: "notional_cap",
    passed: notionalOk,
    detail: { notional, equity, capPct: NOTIONAL_CAP_PCT },
  });
  if (!notionalOk) {
    return reject("notional_cap", checks);
  }

  const leverage = await bybit.leverage(req.symbol);
  if (!isValidLeverage(leverage)) {
    return rejectInput("leverage", leverage, checks);
  }
  const cap = leverageCapFor(req.symbol);
  const leverageOk = leverage <= cap;
  checks.push({
    name: "leverage_cap",
    passed: leverageOk,
    detail: { leverage, cap },
  });
  if (!leverageOk) {
    return reject("leverage_cap", checks);
  }

  const priceOk =
    req.price === undefined ||
    Math.abs(req.price - mark) / mark <= PRICE_SANITY_PCT;
  checks.push({
    name: "price_sanity",
    passed: priceOk,
    detail: { price: req.price, mark, capPct: PRICE_SANITY_PCT },
  });
  if (!priceOk) {
    return reject("price_sanity", checks);
  }

  const positions = await bybit.openPositions();
  const wouldExceedMax = positions.length >= MAX_OPEN_POSITIONS;
  const alreadyOpenOnSymbol = positions.some((p) => p.symbol === req.symbol);
  const positionCapOk = !wouldExceedMax && !alreadyOpenOnSymbol;
  checks.push({
    name: "position_cap",
    passed: positionCapOk,
    detail: {
      openCount: positions.length,
      max: MAX_OPEN_POSITIONS,
      alreadyOpenOnSymbol,
    },
  });
  if (!positionCapOk) {
    return reject("position_cap", checks);
  }

  return pass(checks);
}

/** close_position only needs the kill switch: risk-reducing closures must
 *  stay available even once the daily loss cap has been hit. */
export function checkClose(): GateResult {
  const checks = [checkHalt()];
  if (!checks[0].passed) {
    return reject("kill_switch", checks);
  }
  return pass(checks);
}

export function checkCancel(): GateResult {
  const checks = [checkHalt()];
  if (!checks[0].passed) {
    return reject("kill_switch", checks);
  }
  return pass(checks);
}

export function checkLeverage(symbol: string, leverage: number): GateResult {
  const checks: CheckStep[] = [checkHalt()];
  if (!checks[0].passed) {
    return reject("kill_switch", checks);
  }

  if (!isValidLeverage(leverage)) {
    return rejectInput("leverage", leverage, checks);
  }

  const cap = leverageCapFor(symbol);
  const leverageOk = leverage <= cap;
  checks.push({ name: "leverage_cap", passed: leverageOk, detail: { leverage, cap } });
  if (!leverageOk) {
    return reject("leverage_cap", checks);
  }

  return pass(checks);
}
