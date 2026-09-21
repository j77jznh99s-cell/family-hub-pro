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

  const equity = await bybit.equityUsdt();
  const todayPnl = await bybit.pnlSinceMidnightUtc();
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

  const cap = leverageCapFor(symbol);
  const leverageOk = leverage <= cap;
  checks.push({ name: "leverage_cap", passed: leverageOk, detail: { leverage, cap } });
  if (!leverageOk) {
    return reject("leverage_cap", checks);
  }

  return pass(checks);
}
