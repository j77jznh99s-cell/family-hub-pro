import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { readFileSync } from "node:fs";
import {
  ALLOWED_ENDPOINTS,
  assertAllowedEndpoint,
  findClosablePosition,
  parseExchangeNumber,
  parseLeverage,
  parseMarkPrice,
  parseOpenPositions,
  parseWalletEquity,
  sumClosedPnl,
} from "./bybit.js";

// Pure parsing tests only: nothing here touches the network or credentials.

describe("parseExchangeNumber", () => {
  it("parses numeric strings, including a real zero and negatives", () => {
    assert.equal(parseExchangeNumber("123.45", "f"), 123.45);
    assert.equal(parseExchangeNumber("0", "f"), 0);
    assert.equal(parseExchangeNumber("-12.5", "f"), -12.5);
    assert.equal(parseExchangeNumber(7, "f"), 7);
  });

  it("throws on missing values instead of producing NaN", () => {
    assert.throws(() => parseExchangeNumber(undefined, "f"), /missing/);
    assert.throws(() => parseExchangeNumber(null, "f"), /missing/);
  });

  it("throws on blank strings instead of producing 0", () => {
    assert.throws(() => parseExchangeNumber("", "f"), /blank/);
    assert.throws(() => parseExchangeNumber("   ", "f"), /blank/);
  });

  it("throws on non-numeric and non-finite values", () => {
    assert.throws(() => parseExchangeNumber("abc", "f"), /finite/);
    assert.throws(() => parseExchangeNumber("NaN", "f"), /finite/);
    assert.throws(() => parseExchangeNumber("Infinity", "f"), /finite/);
    assert.throws(() => parseExchangeNumber(Number.NaN, "f"), /finite/);
    assert.throws(() => parseExchangeNumber({}, "f"), /unexpected type/);
    assert.throws(() => parseExchangeNumber(true, "f"), /unexpected type/);
  });

  it("enforces positive and nonNegative options", () => {
    assert.throws(() => parseExchangeNumber("0", "f", { positive: true }), /> 0/);
    assert.throws(() => parseExchangeNumber("-1", "f", { positive: true }), /> 0/);
    assert.equal(parseExchangeNumber("0.5", "f", { positive: true }), 0.5);
    assert.equal(parseExchangeNumber("0", "f", { nonNegative: true }), 0);
    assert.throws(() => parseExchangeNumber("-0.1", "f", { nonNegative: true }), />= 0/);
  });

  it("names the field in the error", () => {
    assert.throws(() => parseExchangeNumber("", "totalEquity"), /totalEquity/);
  });
});

describe("parseWalletEquity", () => {
  it("returns parsed equity", () => {
    assert.equal(parseWalletEquity({ list: [{ totalEquity: "10000.5" }] }), 10000.5);
  });

  it("allows a genuine zero equity string (the gate rejects it separately)", () => {
    assert.equal(parseWalletEquity({ list: [{ totalEquity: "0" }] }), 0);
  });

  it("throws on missing list, empty list, missing or blank equity", () => {
    assert.throws(() => parseWalletEquity({}));
    assert.throws(() => parseWalletEquity({ list: null }));
    assert.throws(() => parseWalletEquity({ list: [] }), /empty/);
    assert.throws(() => parseWalletEquity({ list: [{}] }), /missing/);
    assert.throws(() => parseWalletEquity({ list: [{ totalEquity: "" }] }), /blank/);
  });
});

describe("parseMarkPrice", () => {
  it("returns parsed mark price", () => {
    assert.equal(parseMarkPrice({ list: [{ markPrice: "50000" }] }, "BTCUSDT"), 50000);
  });

  it("throws on blank, zero, missing or empty", () => {
    assert.throws(() => parseMarkPrice({ list: [{ markPrice: "" }] }, "BTCUSDT"), /blank/);
    assert.throws(() => parseMarkPrice({ list: [{ markPrice: "0" }] }, "BTCUSDT"), /> 0/);
    assert.throws(() => parseMarkPrice({ list: [{}] }, "BTCUSDT"), /missing/);
    assert.throws(() => parseMarkPrice({ list: [] }, "BTCUSDT"), /BTCUSDT/);
    assert.throws(() => parseMarkPrice({}, "BTCUSDT"));
  });
});

describe("parseLeverage", () => {
  it("returns parsed leverage", () => {
    assert.equal(parseLeverage({ list: [{ leverage: "3" }] }, "BTCUSDT"), 3);
  });

  it("throws on blank, zero, non-numeric, missing row", () => {
    assert.throws(() => parseLeverage({ list: [{ leverage: "" }] }, "BTCUSDT"), /blank/);
    assert.throws(() => parseLeverage({ list: [{ leverage: "0" }] }, "BTCUSDT"), /> 0/);
    assert.throws(() => parseLeverage({ list: [{ leverage: "x" }] }, "BTCUSDT"), /finite/);
    assert.throws(() => parseLeverage({ list: [{}] }, "BTCUSDT"), /missing/);
    assert.throws(() => parseLeverage({ list: [] }, "BTCUSDT"), /No position/);
  });
});

describe("parseOpenPositions", () => {
  const open = {
    symbol: "BTCUSDT",
    side: "Buy",
    size: "0.01",
    leverage: "2",
    unrealisedPnl: "-3.5",
    markPrice: "50000",
  };
  const flat = {
    symbol: "ETHUSDT",
    side: "",
    size: "0",
    leverage: "",
    unrealisedPnl: "",
    markPrice: "",
  };

  it("keeps open positions and silently drops size-0 rows", () => {
    const result = parseOpenPositions({ list: [open, flat] });
    assert.deepEqual(result, [
      {
        symbol: "BTCUSDT",
        side: "Buy",
        size: 0.01,
        leverage: 2,
        unrealisedPnl: -3.5,
        markPrice: 50000,
      },
    ]);
  });

  it("allows unrealisedPnl of exactly 0", () => {
    const [p] = parseOpenPositions({ list: [{ ...open, unrealisedPnl: "0" }] });
    assert.equal(p?.unrealisedPnl, 0);
  });

  it("returns an empty array for an empty list", () => {
    assert.deepEqual(parseOpenPositions({ list: [] }), []);
  });

  it("throws on blank, missing, negative or non-numeric size", () => {
    assert.throws(() => parseOpenPositions({ list: [{ ...open, size: "" }] }), /blank/);
    assert.throws(() => parseOpenPositions({ list: [{ ...open, size: undefined }] }), /missing/);
    assert.throws(() => parseOpenPositions({ list: [{ ...open, size: "-1" }] }), />= 0/);
    assert.throws(() => parseOpenPositions({ list: [{ ...open, size: "abc" }] }), /finite/);
  });

  it("throws on bad fields of an open position", () => {
    assert.throws(() => parseOpenPositions({ list: [{ ...open, leverage: "" }] }), /leverage/);
    assert.throws(() => parseOpenPositions({ list: [{ ...open, leverage: "0" }] }), /leverage/);
    assert.throws(() => parseOpenPositions({ list: [{ ...open, markPrice: "" }] }), /markPrice/);
    assert.throws(
      () => parseOpenPositions({ list: [{ ...open, unrealisedPnl: "" }] }),
      /unrealisedPnl/
    );
    assert.throws(() => parseOpenPositions({ list: [{ ...open, side: "" }] }), /side/);
    assert.throws(() => parseOpenPositions({ list: [{ ...open, symbol: "" }] }), /symbol/);
  });

  it("throws on a missing list", () => {
    assert.throws(() => parseOpenPositions({}), /no list/);
    assert.throws(() => parseOpenPositions({ list: null }), /no list/);
  });
});

describe("findClosablePosition", () => {
  const row = { symbol: "BTCUSDT", side: "Sell", size: "0.02", leverage: "", markPrice: "" };

  it("returns side and size even when leverage or mark price are blank", () => {
    assert.deepEqual(findClosablePosition({ list: [row] }, "BTCUSDT"), {
      side: "Sell",
      size: 0.02,
    });
  });

  it("skips other symbols and flat rows", () => {
    const list = [{ ...row, symbol: "ETHUSDT" }, { ...row, size: "0" }];
    assert.throws(() => findClosablePosition({ list }, "BTCUSDT"), /No open position/);
  });

  it("throws on blank size or invalid side for the symbol", () => {
    assert.throws(() => findClosablePosition({ list: [{ ...row, size: "" }] }, "BTCUSDT"), /blank/);
    assert.throws(() => findClosablePosition({ list: [{ ...row, side: "" }] }, "BTCUSDT"), /side/);
    assert.throws(() => findClosablePosition({}, "BTCUSDT"), /no list/);
  });
});

describe("sumClosedPnl", () => {
  it("sums closed PnL rows, including zeros", () => {
    assert.equal(
      sumClosedPnl({ list: [{ closedPnl: "10" }, { closedPnl: "-4.5" }, { closedPnl: "0" }] }),
      5.5
    );
  });

  it("returns 0 for an empty page", () => {
    assert.equal(sumClosedPnl({ list: [] }), 0);
  });

  it("throws on blank, missing or non-numeric rows", () => {
    assert.throws(() => sumClosedPnl({ list: [{ closedPnl: "1" }, { closedPnl: "" }] }), /closedPnl\[1\]/);
    assert.throws(() => sumClosedPnl({ list: [{}] }), /missing/);
    assert.throws(() => sumClosedPnl({ list: [{ closedPnl: "oops" }] }), /finite/);
  });

  it("throws when the page has no list", () => {
    assert.throws(() => sumClosedPnl({}), /no list/);
    assert.throws(() => sumClosedPnl({ list: null }), /no list/);
  });
});

describe("endpoint allow-list", () => {
  it("refuses withdraw/transfer and anything not listed, before any network call", () => {
    assert.throws(() => assertAllowedEndpoint("POST", "/v5/asset/withdraw/create"), /allow-list/);
    assert.throws(() => assertAllowedEndpoint("POST", "/v5/asset/transfer/inter-transfer"), /allow-list/);
    assert.throws(() => assertAllowedEndpoint("GET", "/v5/order/create"), /allow-list/);
    assert.doesNotThrow(() => assertAllowedEndpoint("POST", "/v5/order/create"));
  });

  it("covers every endpoint the client calls, and none under /v5/asset/", () => {
    // Every call site sits after signedRequest's definition; the list itself sits before it.
    const src = readFileSync(new URL("../src/bybit.ts", import.meta.url), "utf8").split("async function signedRequest")[1];
    const calls = [...src.matchAll(/"(GET|POST)",\s*"(\/v5\/[^"]+)"/g)].map((m) => `${m[1]} ${m[2]}`);
    assert.ok(calls.length >= 9, `found only ${calls.length} calls`);
    for (const c of calls) assert.ok(ALLOWED_ENDPOINTS.has(c), `${c} missing from allow-list`);
    for (const e of ALLOWED_ENDPOINTS) assert.ok(!e.includes("/v5/asset/"), e);
  });
});
