import crypto from "node:crypto";

const RECV_WINDOW = "5000";
const CATEGORY = "linear";

function baseUrl() {
  return process.env.BYBIT_TESTNET === "true"
    ? "https://api-testnet.bybit.com"
    : "https://api.bybit.com";
}

function credentials() {
  const key = process.env.BYBIT_API_KEY;
  const secret = process.env.BYBIT_API_SECRET;
  if (!key || !secret) {
    throw new Error(
      "BYBIT_API_KEY and BYBIT_API_SECRET must be set in this script's environment. " +
        "Use a read-only key here; only the risk gate needs trading permission."
    );
  }
  return { key, secret };
}

function sign(secret, payload) {
  return crypto.createHmac("sha256", secret).update(payload).digest("hex");
}

async function signedGet(endpoint, params = {}) {
  const { key, secret } = credentials();
  const timestamp = Date.now().toString();
  const cleaned = Object.fromEntries(
    Object.entries(params).filter(([, v]) => v !== undefined && v !== null)
  );
  const query = new URLSearchParams(cleaned).toString();
  const signature = sign(secret, timestamp + key + RECV_WINDOW + query);

  const url = `${baseUrl()}${endpoint}${query ? `?${query}` : ""}`;
  const res = await fetch(url, {
    method: "GET",
    headers: {
      "X-BAPI-API-KEY": key,
      "X-BAPI-TIMESTAMP": timestamp,
      "X-BAPI-RECV-WINDOW": RECV_WINDOW,
      "X-BAPI-SIGN": signature,
    },
  });

  if (!res.ok) {
    throw new Error(`Bybit HTTP ${res.status}: ${await res.text()}`);
  }
  const json = await res.json();
  if (json.retCode !== 0) {
    throw new Error(`Bybit API error ${json.retCode}: ${json.retMsg}`);
  }
  return json.result;
}

/**
 * Strictly parse a numeric field from a Bybit response (same semantics as
 * risk-gate/src/bybit.ts).
 *
 * Bybit encodes numbers as strings. `Number("")` is 0 and `Number(undefined)`
 * is NaN, so a naive `Number(x)` silently turns a missing or blank field into
 * a plausible-looking value. This throws instead, so monitoring reports an
 * error rather than a fake 0.
 *
 * Throws on: undefined, null, non-string/non-number values, blank or
 * whitespace-only strings, and anything that does not parse to a finite
 * number. With `positive: true`, also throws unless the value is > 0.
 * With `nonNegative: true`, also throws if the value is < 0.
 */
export function parseExchangeNumber(value, field, opts = {}) {
  let parsed;
  if (typeof value === "number") {
    parsed = value;
  } else if (typeof value === "string") {
    if (value.trim() === "") {
      throw new Error(`Bybit response field ${field} is blank`);
    }
    parsed = Number(value);
  } else if (value === undefined || value === null) {
    throw new Error(`Bybit response field ${field} is missing`);
  } else {
    throw new Error(`Bybit response field ${field} has unexpected type ${typeof value}`);
  }

  if (!Number.isFinite(parsed)) {
    throw new Error(
      `Bybit response field ${field} is not a finite number: ${JSON.stringify(value)}`
    );
  }
  if (opts.positive && !(parsed > 0)) {
    throw new Error(`Bybit response field ${field} must be > 0, got ${parsed}`);
  }
  if (opts.nonNegative && parsed < 0) {
    throw new Error(`Bybit response field ${field} must be >= 0, got ${parsed}`);
  }
  return parsed;
}

/**
 * Parse an optional price such as a position's stopLoss/takeProfit. Bybit
 * returns "" or "0" when none is set, so those (and missing) mean null.
 * Anything else must be a finite number > 0.
 */
export function parseOptionalPrice(value, field) {
  if (value === undefined || value === null) return null;
  if (typeof value === "string" && (value.trim() === "" || Number(value) === 0)) return null;
  if (value === 0) return null;
  return parseExchangeNumber(value, field, { positive: true });
}

function requireList(list, what) {
  if (!Array.isArray(list)) {
    throw new Error(`Bybit response for ${what} has no list`);
  }
  return list;
}

/** Pure parser for /v5/account/wallet-balance. Exported for tests. */
export function parseEquity(result) {
  const row = requireList(result?.list, "wallet balance")[0];
  if (!row) {
    throw new Error("Bybit wallet balance list is empty; cannot determine equity");
  }
  return parseExchangeNumber(row.totalEquity, "totalEquity");
}

/**
 * Pure parser for /v5/position/list (all USDT positions). Exported for tests.
 *
 * Rows with size "0" (no open position) are skipped without error. A blank,
 * missing, negative or non-numeric size throws, as does a missing list, so a
 * malformed response never looks like "no positions".
 */
export function parsePositions(result) {
  const rows = requireList(result?.list, "position list");
  const positions = [];
  for (const row of rows) {
    const symbol = row?.symbol;
    if (typeof symbol !== "string" || symbol.trim() === "") {
      throw new Error("Bybit position row has a missing or blank symbol");
    }
    const size = parseExchangeNumber(row.size, `size (${symbol})`, { nonNegative: true });
    if (size === 0) continue;

    if (row.side !== "Buy" && row.side !== "Sell") {
      throw new Error(
        `Bybit position ${symbol} has size ${size} but invalid side ${JSON.stringify(row.side)}`
      );
    }
    positions.push({
      symbol,
      side: row.side,
      size,
      entryPrice: parseExchangeNumber(row.avgPrice, `avgPrice (${symbol})`, { positive: true }),
      markPrice: parseExchangeNumber(row.markPrice, `markPrice (${symbol})`, { positive: true }),
      leverage: parseExchangeNumber(row.leverage, `leverage (${symbol})`, { positive: true }),
      unrealisedPnl: parseExchangeNumber(row.unrealisedPnl, `unrealisedPnl (${symbol})`),
      stopLoss: parseOptionalPrice(row.stopLoss, `stopLoss (${symbol})`),
      takeProfit: parseOptionalPrice(row.takeProfit, `takeProfit (${symbol})`),
    });
  }
  return positions;
}

/** Pure sum of one /v5/position/closed-pnl page. Exported for tests. */
export function parseClosedPnl(page) {
  return requireList(page?.list, "closed PnL").reduce(
    (sum, row, i) => sum + parseExchangeNumber(row?.closedPnl, `closedPnl[${i}]`),
    0
  );
}

/**
 * Pure parser for /v5/market/funding/history (limit 1). Exported for tests.
 * An empty list means no funding record and returns null (funding-check skips
 * it); a missing list or a blank/non-numeric rate throws.
 */
export function parseFundingRate(result, symbol) {
  const row = requireList(result?.list, `funding history ${symbol}`)[0];
  if (!row) return null;
  return parseExchangeNumber(row.fundingRate, `fundingRate (${symbol})`);
}

/**
 * Pure parser for /v5/market/tickers mark price. Exported for tests.
 * An empty list returns null; a missing list or a blank/zero price throws.
 */
export function parseMarkPrice(result, symbol) {
  const row = requireList(result?.list, `tickers ${symbol}`)[0];
  if (!row) return null;
  return parseExchangeNumber(row.markPrice, `markPrice (${symbol})`, { positive: true });
}

export async function getEquityUsdt() {
  const result = await signedGet("/v5/account/wallet-balance", { accountType: "UNIFIED" });
  return parseEquity(result);
}

export async function getOpenPositions() {
  const result = await signedGet("/v5/position/list", { category: CATEGORY, settleCoin: "USDT" });
  return parsePositions(result);
}

export async function getClosedPnlToday() {
  const now = new Date();
  const midnightUtc = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  let realized = 0;
  let cursor;
  do {
    const page = await signedGet("/v5/position/closed-pnl", {
      category: CATEGORY,
      startTime: midnightUtc,
      limit: 100,
      cursor,
    });
    realized += parseClosedPnl(page);
    cursor = page.nextPageCursor || undefined;
  } while (cursor);
  return realized;
}

export async function getFundingRate(symbol) {
  const result = await signedGet("/v5/market/funding/history", {
    category: CATEGORY,
    symbol,
    limit: 1,
  });
  return parseFundingRate(result, symbol);
}

export async function getMarkPrice(symbol) {
  const result = await signedGet("/v5/market/tickers", { category: CATEGORY, symbol });
  return parseMarkPrice(result, symbol);
}
