import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { diffPositions, normaliseSnapshot, positionKey } from "./positions.js";

function pos(symbol, side, extra = {}) {
  return {
    symbol,
    side,
    size: 0.01,
    entryPrice: 50000,
    markPrice: 50000,
    leverage: 3,
    unrealisedPnl: 0,
    stopLoss: 48000,
    takeProfit: 52000,
    ...extra,
  };
}

function snapshotOf(...positions) {
  return Object.fromEntries(positions.map((p) => [positionKey(p), p]));
}

describe("positionKey", () => {
  it("combines symbol and side", () => {
    assert.equal(positionKey(pos("BTCUSDT", "Buy")), "BTCUSDT:Buy");
    assert.equal(positionKey(pos("BTCUSDT", "Sell")), "BTCUSDT:Sell");
  });
});

describe("diffPositions", () => {
  it("raises no alerts when nothing changed", () => {
    const buy = pos("BTCUSDT", "Buy");
    const { alerts, snapshot } = diffPositions(snapshotOf(buy), [buy]);
    assert.deepEqual(alerts, []);
    assert.deepEqual(snapshot, { "BTCUSDT:Buy": buy });
  });

  it("detects both legs of a hedge-mode position", () => {
    const buy = pos("BTCUSDT", "Buy");
    const sell = pos("BTCUSDT", "Sell", { entryPrice: 50100 });
    const { alerts, snapshot } = diffPositions({}, [buy, sell]);
    assert.equal(alerts.length, 2);
    assert.match(alerts[0], /^Position detected: BTCUSDT Buy size 0\.01 @ 50000, stop 48000, take profit 52000\.$/);
    assert.match(alerts[1], /^Position detected: BTCUSDT Sell size 0\.01 @ 50100,/);
    assert.deepEqual(Object.keys(snapshot).sort(), ["BTCUSDT:Buy", "BTCUSDT:Sell"]);
  });

  it("alerts only the hedge leg that closed while the other stays open", () => {
    const buy = pos("BTCUSDT", "Buy");
    const sell = pos("BTCUSDT", "Sell", { markPrice: 52010, unrealisedPnl: -0.2 });
    const { alerts, snapshot } = diffPositions(snapshotOf(buy, sell), [buy]);
    assert.equal(alerts.length, 1);
    assert.match(alerts[0], /^Position closed: BTCUSDT Sell — likely take-profit\. Last unrealised PnL -0\.2\.$/);
    assert.deepEqual(snapshot, { "BTCUSDT:Buy": buy });
  });

  it("catches a one-way-mode side flip as a closed Buy plus a detected Sell", () => {
    const buy = pos("ETHUSDT", "Buy", { markPrice: 48010 });
    const sell = pos("ETHUSDT", "Sell");
    const { alerts, snapshot } = diffPositions(snapshotOf(buy), [sell]);
    assert.equal(alerts.length, 2);
    assert.match(alerts[0], /^Position closed: ETHUSDT Buy — likely stop-out\./);
    assert.match(alerts[1], /^Position detected: ETHUSDT Sell /);
    assert.deepEqual(snapshot, { "ETHUSDT:Sell": sell });
  });

  it("raises no alerts on an old symbol-keyed snapshot when nothing changed", () => {
    const btc = pos("BTCUSDT", "Buy");
    const eth = pos("ETHUSDT", "Sell");
    const oldSnapshot = { BTCUSDT: btc, ETHUSDT: eth };
    const { alerts, snapshot } = diffPositions(oldSnapshot, [btc, eth]);
    assert.deepEqual(alerts, []);
    assert.deepEqual(snapshot, { "BTCUSDT:Buy": btc, "ETHUSDT:Sell": eth });
  });

  it("still alerts a real close from an old symbol-keyed snapshot", () => {
    const btc = pos("BTCUSDT", "Buy");
    const { alerts } = diffPositions({ BTCUSDT: btc }, []);
    assert.equal(alerts.length, 1);
    assert.match(alerts[0], /^Position closed: BTCUSDT Buy — /);
  });

  it("ignores garbage snapshot entries without crashing", () => {
    const btc = pos("BTCUSDT", "Buy");
    const garbage = {
      BTCUSDT: btc,
      a: null,
      b: 42,
      c: "text",
      d: [1, 2],
      e: { symbol: "XRPUSDT" },
      f: { symbol: "XRPUSDT", side: "Long" },
      g: { symbol: "", side: "Buy" },
      h: { side: "Sell" },
    };
    const { alerts, snapshot } = diffPositions(garbage, [btc]);
    assert.deepEqual(alerts, []);
    assert.deepEqual(snapshot, { "BTCUSDT:Buy": btc });
  });

  it("treats a non-object snapshot as empty", () => {
    const btc = pos("BTCUSDT", "Buy");
    for (const raw of [null, undefined, [], [btc], 7, "x", true]) {
      const { alerts } = diffPositions(raw, [btc]);
      assert.equal(alerts.length, 1, `snapshot ${JSON.stringify(raw)}`);
      assert.match(alerts[0], /^Position detected: BTCUSDT Buy /);
    }
  });

  it("raises no alerts when both snapshot and positions are empty", () => {
    assert.deepEqual(diffPositions({}, []), { alerts: [], snapshot: {} });
  });
});

describe("normaliseSnapshot", () => {
  it("keeps an already symbol:side keyed snapshot unchanged", () => {
    const buy = pos("BTCUSDT", "Buy");
    const sell = pos("BTCUSDT", "Sell");
    const snap = snapshotOf(buy, sell);
    assert.deepEqual(normaliseSnapshot(snap), snap);
  });
});
