import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  parseClosedPnl,
  parseEquity,
  parseExchangeNumber,
  parseFundingRate,
  parseMarkPrice,
  parseOptionalPrice,
  parsePositions,
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
    assert.throws(() => parseExchangeNumber(undefined, "totalEquity"), /totalEquity/);
    assert.throws(() => parseExchangeNumber("x", "totalEquity"), /totalEquity/);
  });
});

describe("parseOptionalPrice", () => {
  it("treats missing, blank and zero as no level set", () => {
    assert.equal(parseOptionalPrice(undefined, "stopLoss"), null);
    assert.equal(parseOptionalPrice(null, "stopLoss"), null);
    assert.equal(parseOptionalPrice("", "stopLoss"), null);
    assert.equal(parseOptionalPrice("  ", "stopLoss"), null);
    assert.equal(parseOptionalPrice("0", "stopLoss"), null);
    assert.equal(parseOptionalPrice("0.00", "stopLoss"), null);
    assert.equal(parseOptionalPrice(0, "stopLoss"), null);
  });

  it("parses a real price", () => {
    assert.equal(parseOptionalPrice("48000.5", "stopLoss"), 48000.5);
  });

  it("throws on negative or non-numeric prices, naming the field", () => {
    assert.throws(() => parseOptionalPrice("-1", "stopLoss"), /stopLoss.*> 0/);
    assert.throws(() => parseOptionalPrice("abc", "takeProfit"), /takeProfit.*finite/);
  });
});

describe("parseEquity", () => {
  it("returns parsed equity", () => {
    assert.equal(parseEquity({ list: [{ totalEquity: "10000.5" }] }), 10000.5);
  });

  it("allows a genuine zero equity string", () => {
    assert.equal(parseEquity({ list: [{ totalEquity: "0" }] }), 0);
  });

  it("throws on missing list, empty list, missing or blank equity", () => {
    assert.throws(() => parseEquity({}), /no list/);
    assert.throws(() => parseEquity({ list: null }), /no list/);
    assert.throws(() => parseEquity(undefined), /no list/);
    assert.throws(() => parseEquity({ list: [] }), /empty/);
    assert.throws(() => parseEquity({ list: [{}] }), /totalEquity is missing/);
    assert.throws(() => parseEquity({ list: [{ totalEquity: "" }] }), /totalEquity is blank/);
  });
});

describe("parsePositions", () => {
  const open = {
    symbol: "BTCUSDT",
    side: "Buy",
    size: "0.01",
    avgPrice: "49000",
    markPrice: "50000",
    leverage: "2",
    unrealisedPnl: "-3.5",
    stopLoss: "48000",
    takeProfit: "52000",
  };
  const flat = {
    symbol: "ETHUSDT",
    side: "",
    size: "0",
    avgPrice: "",
    markPrice: "",
    leverage: "",
    unrealisedPnl: "",
    stopLoss: "",
    takeProfit: "",
  };

  it("parses open positions and silently drops size-0 rows", () => {
    assert.deepEqual(parsePositions({ list: [open, flat] }), [
      {
        symbol: "BTCUSDT",
        side: "Buy",
        size: 0.01,
        entryPrice: 49000,
        markPrice: 50000,
        leverage: 2,
        unrealisedPnl: -3.5,
        stopLoss: 48000,
        takeProfit: 52000,
      },
    ]);
  });

  it('maps "" and "0" stop/take profit to null', () => {
    const [a] = parsePositions({ list: [{ ...open, stopLoss: "", takeProfit: "0" }] });
    assert.equal(a.stopLoss, null);
    assert.equal(a.takeProfit, null);
    const [b] = parsePositions({ list: [{ ...open, stopLoss: "0", takeProfit: undefined }] });
    assert.equal(b.stopLoss, null);
    assert.equal(b.takeProfit, null);
  });

  it("allows unrealisedPnl of exactly 0", () => {
    const [p] = parsePositions({ list: [{ ...open, unrealisedPnl: "0" }] });
    assert.equal(p.unrealisedPnl, 0);
  });

  it("returns an empty array for an empty list", () => {
    assert.deepEqual(parsePositions({ list: [] }), []);
  });

  it("throws on a missing list instead of reporting no positions", () => {
    assert.throws(() => parsePositions({}), /no list/);
    assert.throws(() => parsePositions({ list: null }), /no list/);
    assert.throws(() => parsePositions(undefined), /no list/);
  });

  it("throws on blank, missing, negative or non-numeric size", () => {
    assert.throws(() => parsePositions({ list: [{ ...open, size: "" }] }), /size \(BTCUSDT\) is blank/);
    assert.throws(() => parsePositions({ list: [{ ...open, size: undefined }] }), /missing/);
    assert.throws(() => parsePositions({ list: [{ ...open, size: "-1" }] }), />= 0/);
    assert.throws(() => parsePositions({ list: [{ ...open, size: "abc" }] }), /finite/);
  });

  it("throws on bad fields of an open position, naming the field", () => {
    assert.throws(() => parsePositions({ list: [{ ...open, avgPrice: "" }] }), /avgPrice/);
    assert.throws(() => parsePositions({ list: [{ ...open, markPrice: "" }] }), /markPrice/);
    assert.throws(() => parsePositions({ list: [{ ...open, markPrice: "0" }] }), /markPrice/);
    assert.throws(() => parsePositions({ list: [{ ...open, leverage: "" }] }), /leverage/);
    assert.throws(() => parsePositions({ list: [{ ...open, leverage: "0" }] }), /leverage/);
    assert.throws(() => parsePositions({ list: [{ ...open, unrealisedPnl: "" }] }), /unrealisedPnl/);
    assert.throws(() => parsePositions({ list: [{ ...open, unrealisedPnl: "NaN" }] }), /unrealisedPnl/);
    assert.throws(() => parsePositions({ list: [{ ...open, stopLoss: "abc" }] }), /stopLoss/);
    assert.throws(() => parsePositions({ list: [{ ...open, side: "" }] }), /side/);
    assert.throws(() => parsePositions({ list: [{ ...open, symbol: "" }] }), /symbol/);
  });
});

describe("parseClosedPnl", () => {
  it("sums closed PnL rows, including zeros", () => {
    assert.equal(
      parseClosedPnl({ list: [{ closedPnl: "10" }, { closedPnl: "-4.5" }, { closedPnl: "0" }] }),
      5.5
    );
  });

  it("returns 0 for an empty page", () => {
    assert.equal(parseClosedPnl({ list: [] }), 0);
  });

  it("throws on blank, missing or non-numeric rows", () => {
    assert.throws(
      () => parseClosedPnl({ list: [{ closedPnl: "1" }, { closedPnl: "" }] }),
      /closedPnl\[1\] is blank/
    );
    assert.throws(() => parseClosedPnl({ list: [{}] }), /missing/);
    assert.throws(() => parseClosedPnl({ list: [{ closedPnl: "oops" }] }), /finite/);
  });

  it("throws when the page has no list", () => {
    assert.throws(() => parseClosedPnl({}), /no list/);
    assert.throws(() => parseClosedPnl({ list: null }), /no list/);
  });
});

describe("parseFundingRate", () => {
  it("parses positive, negative and zero rates", () => {
    assert.equal(parseFundingRate({ list: [{ fundingRate: "0.0001" }] }, "BTCUSDT"), 0.0001);
    assert.equal(parseFundingRate({ list: [{ fundingRate: "-0.0004" }] }, "BTCUSDT"), -0.0004);
    assert.equal(parseFundingRate({ list: [{ fundingRate: "0" }] }, "BTCUSDT"), 0);
  });

  it("returns null when there is no funding record", () => {
    assert.equal(parseFundingRate({ list: [] }, "BTCUSDT"), null);
  });

  it("throws on blank or missing rate and on a missing list", () => {
    assert.throws(
      () => parseFundingRate({ list: [{ fundingRate: "" }] }, "BTCUSDT"),
      /fundingRate \(BTCUSDT\) is blank/
    );
    assert.throws(() => parseFundingRate({ list: [{}] }, "BTCUSDT"), /missing/);
    assert.throws(() => parseFundingRate({}, "BTCUSDT"), /no list/);
  });
});

describe("parseMarkPrice", () => {
  it("returns parsed mark price", () => {
    assert.equal(parseMarkPrice({ list: [{ markPrice: "50000" }] }, "BTCUSDT"), 50000);
  });

  it("returns null when there is no ticker row", () => {
    assert.equal(parseMarkPrice({ list: [] }, "BTCUSDT"), null);
  });

  it("throws on blank, zero or missing price and on a missing list", () => {
    assert.throws(() => parseMarkPrice({ list: [{ markPrice: "" }] }, "BTCUSDT"), /blank/);
    assert.throws(() => parseMarkPrice({ list: [{ markPrice: "0" }] }, "BTCUSDT"), /> 0/);
    assert.throws(() => parseMarkPrice({ list: [{}] }, "BTCUSDT"), /missing/);
    assert.throws(() => parseMarkPrice({}, "BTCUSDT"), /no list/);
  });
});
