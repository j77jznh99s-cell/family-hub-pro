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
        list: Array<{ totalEquity: string }>;
      }>("GET", "/v5/account/wallet-balance", { accountType: "UNIFIED" });
      const equity = Number(result.list?.[0]?.totalEquity ?? "0");
      if (!Number.isFinite(equity)) {
        throw new Error("Could not parse account equity from Bybit response");
      }
      return equity;
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
          list: Array<{ closedPnl: string }>;
          nextPageCursor?: string;
        } = await signedRequest("GET", "/v5/position/closed-pnl", {
          category: CATEGORY,
          startTime: midnightUtc,
          limit: 100,
          cursor,
        });
        realized += page.list.reduce((sum, row) => sum + Number(row.closedPnl), 0);
        cursor = page.nextPageCursor || undefined;
      } while (cursor);

      const positions = await this.openPositions();
      const unrealized = positions.reduce((sum, p) => sum + p.unrealisedPnl, 0);

      return realized + unrealized;
    },

    async markPrice(symbol: string): Promise<number> {
      const result = await signedRequest<{
        list: Array<{ markPrice: string }>;
      }>("GET", "/v5/market/tickers", { category: CATEGORY, symbol });
      const mark = Number(result.list?.[0]?.markPrice);
      if (!Number.isFinite(mark)) {
        throw new Error(`Could not resolve mark price for ${symbol}`);
      }
      return mark;
    },

    async leverage(symbol: string): Promise<number> {
      const result = await signedRequest<{
        list: Array<{ leverage: string }>;
      }>("GET", "/v5/position/list", { category: CATEGORY, symbol });
      const row = result.list?.[0];
      if (!row) {
        throw new Error(`No position/leverage record for ${symbol}`);
      }
      return Number(row.leverage);
    },

    async openPositions(): Promise<Position[]> {
      const result = await signedRequest<{
        list: Array<{
          symbol: string;
          side: ExchangeSide | "";
          size: string;
          leverage: string;
          unrealisedPnl: string;
          markPrice: string;
        }>;
      }>("GET", "/v5/position/list", { category: CATEGORY, settleCoin: "USDT" });

      return result.list
        .filter((p) => Number(p.size) > 0)
        .map((p) => ({
          symbol: p.symbol,
          side: p.side as ExchangeSide,
          size: Number(p.size),
          leverage: Number(p.leverage),
          unrealisedPnl: Number(p.unrealisedPnl),
          markPrice: Number(p.markPrice),
        }));
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
      const positions = await this.openPositions();
      const position = positions.find((p) => p.symbol === symbol);
      if (!position) {
        throw new Error(`No open position on ${symbol} to close`);
      }
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
