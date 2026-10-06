import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { guessOutcome } from "./outcome.js";

const UNCLEAR = /reason unclear/;

describe("guessOutcome", () => {
  it("detects a stop-out near the stop", () => {
    assert.equal(guessOutcome({ markPrice: 48010, stopLoss: 48000, takeProfit: 52000 }), "likely stop-out");
  });

  it("detects a take-profit near the target", () => {
    assert.equal(
      guessOutcome({ markPrice: 51990, stopLoss: 48000, takeProfit: 52000 }),
      "likely take-profit"
    );
  });

  it("is unclear when the mark is far from both levels", () => {
    assert.match(guessOutcome({ markPrice: 50000, stopLoss: 48000, takeProfit: 52000 }), UNCLEAR);
  });

  it("does not divide by a null or 0 stop/take profit", () => {
    for (const level of [null, 0, undefined, Number.NaN]) {
      const result = guessOutcome({ markPrice: 0.001, stopLoss: level, takeProfit: level });
      assert.match(result, UNCLEAR);
    }
  });

  it("still uses the take profit when only the stop is 0", () => {
    assert.equal(guessOutcome({ markPrice: 52000, stopLoss: 0, takeProfit: 52000 }), "likely take-profit");
  });

  it("is unclear when the mark price is missing or 0", () => {
    assert.match(guessOutcome({ stopLoss: 48000, takeProfit: 52000 }), UNCLEAR);
    assert.match(guessOutcome({ markPrice: 0, stopLoss: 48000, takeProfit: 52000 }), UNCLEAR);
    assert.match(guessOutcome({}), UNCLEAR);
  });
});
