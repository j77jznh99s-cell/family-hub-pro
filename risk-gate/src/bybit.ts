import crypto from "node:crypto";
import type { BybitClient, ExchangeSide, OrderRequest, Position } from "./types.js";

const RECV_WINDOW = "5000";
const CATEGORY = "linear";

interface BybitResponse<T> {
  retCode: number;
  retMsg: string;
  result: T;
}

function baseUrl(): string {
  return process.env.BYBIT_TESTNET === "true"
    ? "https://api-testnet.bybit.com"
    : "https://api.bybit.com";
}

function credentials(): { key: string; secret: string } {
  const key = process.env.BYBIT_API_KEY;
  const secret = process.env.BYBIT_API_SECRET;
  if (!key || !secret) {
    throw new Error(
      "BYBIT_API_KEY and BYBIT_API_SECRET must be set in the risk-gate's own " +
        "environment (in ~/.codex/config.toml's [mcp_servers.risk-gate] env " +
        "block). The gate refuses to start without them."
    );
  }
  return { key, secret };
}

function sign(secret: string, payload: string): string {
  return crypto.createHmac("sha256", secret).update(payload).digest("hex");
}

async function signedRequest<T>(
  method: "GET" | "POST",
  endpoint: string,
  params: Record<string, unknown> = {}
): Promise<T> {
  const { key, secret } = credentials();
  const timestamp = Date.now().toString();
  let url = `${baseUrl()}${endpoint}`;
  let body = "";
  let signaturePayload: string;

  if (method === "GET") {
    const cleaned = Object.fromEntries(
      Object.entries(params).filter(([, v]) => v !== undefined && v !== null)
    ) as Record<string, string>;
    const query = new URLSearchParams(cleaned).toString();
    if (query) url += `?${query}`;
    signaturePayload = timestamp + key + RECV_WINDOW + query;
  } else {
    body = JSON.stringify(params);
    signaturePayload = timestamp + key + RECV_WINDOW + body;
  }

  const signature = sign(secret, signaturePayload);

  const res = await fetch(url, {
    method,
    headers: {
      "X-BAPI-API-KEY": key,
      "X-BAPI-TIMESTAMP": timestamp,
      "X-BAPI-RECV-WINDOW": RECV_WINDOW,
      "X-BAPI-SIGN": signature,
      "Content-Type": "application/json",
    },
    body: method === "POST" ? body : undefined,
  });

  if (!res.ok) {
    throw new Error(`Bybit HTTP ${res.status}: ${await res.text()}`);
  }

  const json = (await res.json()) as BybitResponse<T>;
  if (json.retCode !== 0) {
    throw new Error(`Bybit API error ${json.retCode}: ${json.retMsg}`);
  }
  return json.result;
}

/**
 * Strictly parse a numeric field from a Bybit response.
 *
 * Bybit encodes numbers as strings. `Number("")` is 0 and `Number(undefined)`
 * is NaN, so a naive `Number(x)` silently turns a missing or blank field into
 * a plausible-looking value. This throws instead, so the risk gate fails
 * closed on malformed exchange data rather than reasoning about a fake 0.
 *
 * Throws on: undefined, null, non-string/non-number values, blank or
 * whitespace-only strings, and anything that does not parse to a finite
 * number. With `positive: true`, also throws unless the value is > 0.
 * With `nonNegative: true`, also throws if the value is < 0.
 */
export function parseExchangeNumber(
  value: unknown,
  field: string,
  opts: { positive?: boolean; nonNegative?: boolean } = {}
): number {
  let parsed: number;
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

function requireList<T>(list: T[] | undefined | null, what: string): T[] {
  if (!Array.isArray(list)) {
    throw new Error(`Bybit response for ${what} has no list`);
  }
  return list;
}

/** Pure parser for /v5/account/wallet-balance. Exported for tests. */
export function parseWalletEquity(result: {
  list?: Array<{ totalEquity?: unknown }> | null;
}): number {
  const row = requireList(result?.list, "wallet balance")[0];
  if (!row) {
    throw new Error("Bybit wallet balance list is empty; cannot determine equity");
  }
  return parseExchangeNumber(row.totalEquity, "totalEquity");
}

/** Pure parser for /v5/market/tickers mark price. Exported for tests. */
export function parseMarkPrice(
  result: { list?: Array<{ markPrice?: unknown }> | null },
  symbol: string
): number {
  const row = requireList(result?.list, `tickers ${symbol}`)[0];
  if (!row) {
    throw new Error(`Could not resolve mark price for ${symbol}: empty ticker list`);
  }
  return parseExchangeNumber(row.markPrice, `markPrice (${symbol})`, { positive: true });
}

/** Pure parser for /v5/position/list leverage. Exported for tests. */
export function parseLeverage(
  result: { list?: Array<{ leverage?: unknown }> | null },
  symbol: string
): number {
  const row = requireList(result?.list, `position list ${symbol}`)[0];
  if (!row) {
    throw new Error(`No position/leverage record for ${symbol}`);
  }
  return parseExchangeNumber(row.leverage, `leverage (${symbol})`, { positive: true });
}

function isExchangeSide(value: unknown): value is ExchangeSide {
  return value === "Buy" || value === "Sell";
}

export interface RawPositionRow {
  symbol?: unknown;
  side?: unknown;
  size?: unknown;
  leverage?: unknown;
  unrealisedPnl?: unknown;
  markPrice?: unknown;
}

/**
 * Pure parser for /v5/position/list (all USDT positions). Exported for tests.
 *
 * Bybit returns rows with size "0" for symbols that have no open position;
 * those are filtered out without error. A blank, missing, negative or
 * non-numeric size throws. For rows that are kept, side must be Buy/Sell and
 * leverage/markPrice must be > 0 and unrealisedPnl finite (0 allowed).
 */
export function parseOpenPositions(result: {
  list?: RawPositionRow[] | null;
}): Position[] {
  const rows = requireList(result?.list, "position list");
  const positions: Position[] = [];
  for (const row of rows) {
    const symbol = row.symbol;
    if (typeof symbol !== "string" || symbol.trim() === "") {
      throw new Error("Bybit position row has a missing or blank symbol");
    }
    const size = parseExchangeNumber(row.size, `size (${symbol})`, { nonNegative: true });
    if (size === 0) continue;

    const side = row.side;
    if (!isExchangeSide(side)) {
      throw new Error(
        `Bybit position ${symbol} has size ${size} but invalid side ${JSON.stringify(side)}`
      );
    }
    positions.push({
      symbol,
      side,
      size,
      leverage: parseExchangeNumber(row.leverage, `leverage (${symbol})`, { positive: true }),
      unrealisedPnl: parseExchangeNumber(row.unrealisedPnl, `unrealisedPnl (${symbol})`),
      markPrice: parseExchangeNumber(row.markPrice, `markPrice (${symbol})`, { positive: true }),
    });
  }
  return positions;
}

/**
 * Pure parser for closing one position. Exported for tests.
 *
 * Closing reduces risk, so it only needs the fields the close order uses
 * (side and size) and stays strict on those. A blank leverage or mark price
 * on the row must not stop a position from being closed.
 */
export function findClosablePosition(
  result: { list?: RawPositionRow[] | null },
  symbol: string
): { side: ExchangeSide; size: number } {
  for (const row of requireList(result?.list, "position list")) {
    if (row.symbol !== symbol) continue;
    const size = parseExchangeNumber(row.size, `size (${symbol})`, { nonNegative: true });
    if (size === 0) continue;
    if (!isExchangeSide(row.side)) {
      throw new Error(
        `Bybit position ${symbol} has size ${size} but invalid side ${JSON.stringify(row.side)}`
      );
    }
    return { side: row.side, size };
  }
  throw new Error(`No open position on ${symbol} to close`);
}

/** Pure sum of one /v5/position/closed-pnl page. Exported for tests. */
export function sumClosedPnl(page: {
  list?: Array<{ closedPnl?: unknown }> | null;
}): number {
  return requireList(page?.list, "closed PnL").reduce(
    (sum, row, i) => sum + parseExchangeNumber(row.closedPnl, `closedPnl[${i}]`),
    0
  );
}

function toExchangeSide(side: "long" | "short"): ExchangeSide {
  return side === "long" ? "Buy" : "Sell";
}

function oppositeSide(side: ExchangeSide): ExchangeSide {
  return side === "Buy" ? "Sell" : "Buy";
}

export function createBybitClient(): BybitClient {
  return {
    async equityUsdt(): Promise<number> {
      const result = await signedRequest<{
        list?: Array<{ totalEquity?: unknown }> | null;
      }>("GET", "/v5/account/wallet-balance", { accountType: "UNIFIED" });
      return parseWalletEquity(result);
    },

    async pnlSinceMidnightUtc(): Promise<number> {
      const now = new Date();
      const midnightUtc = Date.UTC(
        now.getUTCFullYear(),
        now.getUTCMonth(),
        now.getUTCDate()
      );

      // Closed PnL is paginated at up to 100 rows per Bybit call. A day with
      // more than 100 closed trades would under-count realized loss here;
      // walk the cursor rather than assuming a single page is complete.
      let realized = 0;
      let cursor: string | undefined;
      do {
        const page: {
          list?: Array<{ closedPnl?: unknown }> | null;
          nextPageCursor?: string;
        } = await signedRequest("GET", "/v5/position/closed-pnl", {
          category: CATEGORY,
          startTime: midnightUtc,
          limit: 100,
          cursor,
        });
        realized += sumClosedPnl(page);
        cursor = page.nextPageCursor || undefined;
      } while (cursor);

      const positions = await this.openPositions();
      const unrealized = positions.reduce((sum, p) => sum + p.unrealisedPnl, 0);

      return realized + unrealized;
    },

    async markPrice(symbol: string): Promise<number> {
      const result = await signedRequest<{
        list?: Array<{ markPrice?: unknown }> | null;
      }>("GET", "/v5/market/tickers", { category: CATEGORY, symbol });
      return parseMarkPrice(result, symbol);
    },

    async leverage(symbol: string): Promise<number> {
      const result = await signedRequest<{
        list?: Array<{ leverage?: unknown }> | null;
      }>("GET", "/v5/position/list", { category: CATEGORY, symbol });
      return parseLeverage(result, symbol);
    },

    async openPositions(): Promise<Position[]> {
      const result = await signedRequest<{ list?: RawPositionRow[] | null }>(
        "GET",
        "/v5/position/list",
        { category: CATEGORY, settleCoin: "USDT" }
      );
      return parseOpenPositions(result);
    },

    async placeOrder(req: OrderRequest): Promise<unknown> {
      return signedRequest("POST", "/v5/order/create", {
        category: CATEGORY,
        symbol: req.symbol,
        side: toExchangeSide(req.side),
        orderType: "Market",
        qty: String(req.qty),
        stopLoss: req.stop !== undefined ? String(req.stop) : undefined,
        takeProfit: req.take_profit !== undefined ? String(req.take_profit) : undefined,
      });
    },

    async closePosition(symbol: string): Promise<unknown> {
      const result = await signedRequest<{ list?: RawPositionRow[] | null }>(
        "GET",
        "/v5/position/list",
        { category: CATEGORY, symbol }
      );
      const position = findClosablePosition(result, symbol);
      return signedRequest("POST", "/v5/order/create", {
        category: CATEGORY,
        symbol,
        side: oppositeSide(position.side),
        orderType: "Market",
        qty: String(position.size),
        reduceOnly: true,
      });
    },

    async setLeverage(symbol: string, leverage: number): Promise<unknown> {
      return signedRequest("POST", "/v5/position/set-leverage", {
        category: CATEGORY,
        symbol,
        buyLeverage: String(leverage),
        sellLeverage: String(leverage),
      });
    },

    async cancelOrder(symbol: string, orderId: string): Promise<unknown> {
      return signedRequest("POST", "/v5/order/cancel", {
        category: CATEGORY,
        symbol,
        orderId,
      });
    },
  };
}
