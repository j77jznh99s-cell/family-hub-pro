import assert from "node:assert/strict";
import fs from "node:fs";
import { after, before, beforeEach, describe, it } from "node:test";
import { HALT_FILE } from "./paths.js";
import { checkClose, checkLeverage, checkOrder } from "./checks.js";
import type { BybitClient, OrderRequest, Position } from "./types.js";

function fakeBybit(overrides: Partial<BybitClient> = {}): BybitClient {
  const positions: Position[] = [];
  return {
    equityUsdt: async () => 10_000,
    pnlSinceMidnightUtc: async () => 0,
    markPrice: async () => 50_000,
    leverage: async () => 1,
    openPositions: async () => positions,
    placeOrder: async () => ({ orderId: "test" }),
    closePosition: async () => ({ orderId: "test" }),
    setLeverage: async () => ({}),
    cancelOrder: async () => ({}),
    ...overrides,
  };
}

const baseOrder: OrderRequest = {
  symbol: "BTCUSDT",
  side: "long",
  qty: 0.01, // 0.01 * 50000 = 500, well under the 30% notional cap on 10k equity
  stop: 49000,
  take_profit: 53000,
};

describe("checkOrder", () => {
  beforeEach(() => {
    if (fs.existsSync(HALT_FILE)) fs.rmSync(HALT_FILE);
  });
  after(() => {
    if (fs.existsSync(HALT_FILE)) fs.rmSync(HALT_FILE);
  });

  it("approves a well-formed order inside all limits", async () => {
    const result = await checkOrder(baseOrder, fakeBybit());
    assert.equal(result.approved, true);
    assert.ok(result.checks.every((c) => c.passed));
  });

  it("rejects when HALT_TRADING exists", async () => {
    fs.writeFileSync(HALT_FILE, "");
    const result = await checkOrder(baseOrder, fakeBybit());
    assert.equal(result.approved, false);
    assert.equal(result.reason, "kill_switch");
  });

  it("rejects when daily loss exceeds 5% of equity", async () => {
    const bybit = fakeBybit({ pnlSinceMidnightUtc: async () => -600 }); // -6% of 10k
    const result = await checkOrder(baseOrder, bybit);
    assert.equal(result.approved, false);
    assert.equal(result.reason, "daily_loss_cap");
  });

  it("allows an order right at the 5% daily loss boundary", async () => {
    const bybit = fakeBybit({ pnlSinceMidnightUtc: async () => -500 }); // exactly -5%
    const result = await checkOrder(baseOrder, bybit);
    assert.equal(result.approved, true);
  });

  it("rejects when notional exceeds 30% of equity", async () => {
    const order = { ...baseOrder, qty: 0.1 }; // 0.1 * 50000 = 5000 = 50% of 10k
    const result = await checkOrder(order, fakeBybit());
    assert.equal(result.approved, false);
    assert.equal(result.reason, "notional_cap");
  });

  it("rejects BTC leverage above 10x", async () => {
    const bybit = fakeBybit({ leverage: async () => 11 });
    const result = await checkOrder(baseOrder, bybit);
    assert.equal(result.approved, false);
    assert.equal(result.reason, "leverage_cap");
  });

  it("rejects ETH/SOL leverage above 5x while allowing BTC at the same value", async () => {
    const bybit = fakeBybit({ leverage: async () => 6 });
    const ethResult = await checkOrder({ ...baseOrder, symbol: "ETHUSDT" }, bybit);
    assert.equal(ethResult.approved, false);
    assert.equal(ethResult.reason, "leverage_cap");

    const btcResult = await checkOrder(baseOrder, fakeBybit({ leverage: async () => 6 }));
    assert.equal(btcResult.approved, true);
  });

  it("rejects a limit price more than 2% from mark", async () => {
    const order = { ...baseOrder, price: 52000 }; // ~4% away from 50000 mark
    const result = await checkOrder(order, fakeBybit());
    assert.equal(result.approved, false);
    assert.equal(result.reason, "price_sanity");
  });

  it("rejects a 4th concurrent position", async () => {
    const bybit = fakeBybit({
      openPositions: async () => [
        { symbol: "ETHUSDT", side: "Buy", size: 1, leverage: 3, unrealisedPnl: 0, markPrice: 3000 },
        { symbol: "SOLUSDT", side: "Buy", size: 1, leverage: 3, unrealisedPnl: 0, markPrice: 100 },
        { symbol: "XRPUSDT", side: "Buy", size: 1, leverage: 3, unrealisedPnl: 0, markPrice: 1 },
      ],
    });
    const result = await checkOrder(baseOrder, bybit);
    assert.equal(result.approved, false);
    assert.equal(result.reason, "position_cap");
  });

  it("rejects a second entry on a symbol that already has a position", async () => {
    const bybit = fakeBybit({
      openPositions: async () => [
        { symbol: "BTCUSDT", side: "Buy", size: 0.02, leverage: 5, unrealisedPnl: 0, markPrice: 50000 },
      ],
    });
    const result = await checkOrder(baseOrder, bybit);
    assert.equal(result.approved, false);
    assert.equal(result.reason, "position_cap");
  });
});

describe("checkClose", () => {
  before(() => {
    if (fs.existsSync(HALT_FILE)) fs.rmSync(HALT_FILE);
  });
  after(() => {
    if (fs.existsSync(HALT_FILE)) fs.rmSync(HALT_FILE);
  });

  it("allows closures when not halted", () => {
    if (fs.existsSync(HALT_FILE)) fs.rmSync(HALT_FILE);
    assert.equal(checkClose().approved, true);
  });

  it("blocks closures too once the kill switch is on", () => {
    fs.writeFileSync(HALT_FILE, "");
    const result = checkClose();
    assert.equal(result.approved, false);
    assert.equal(result.reason, "kill_switch");
    fs.rmSync(HALT_FILE);
  });
});

describe("checkLeverage", () => {
  after(() => {
    if (fs.existsSync(HALT_FILE)) fs.rmSync(HALT_FILE);
  });

  it("approves leverage at the symbol cap", () => {
    assert.equal(checkLeverage("BTCUSDT", 10).approved, true);
    assert.equal(checkLeverage("ETHUSDT", 5).approved, true);
  });

  it("rejects leverage above the symbol cap", () => {
    assert.equal(checkLeverage("BTCUSDT", 11).approved, false);
    assert.equal(checkLeverage("SOLUSDT", 6).approved, false);
  });
});
