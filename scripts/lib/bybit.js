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

export async function getEquityUsdt() {
  const result = await signedGet("/v5/account/wallet-balance", { accountType: "UNIFIED" });
  return Number(result.list?.[0]?.totalEquity ?? "0");
}

export async function getOpenPositions() {
  const result = await signedGet("/v5/position/list", { category: CATEGORY, settleCoin: "USDT" });
  return (result.list ?? [])
    .filter((p) => Number(p.size) > 0)
    .map((p) => ({
      symbol: p.symbol,
      side: p.side,
      size: Number(p.size),
      entryPrice: Number(p.avgPrice),
      markPrice: Number(p.markPrice),
      leverage: Number(p.leverage),
      unrealisedPnl: Number(p.unrealisedPnl),
      stopLoss: p.stopLoss ? Number(p.stopLoss) : null,
      takeProfit: p.takeProfit ? Number(p.takeProfit) : null,
    }));
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
    realized += (page.list ?? []).reduce((sum, row) => sum + Number(row.closedPnl), 0);
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
  const row = result.list?.[0];
  return row ? Number(row.fundingRate) : null;
}

export async function getMarkPrice(symbol) {
  const result = await signedGet("/v5/market/tickers", { category: CATEGORY, symbol });
  const row = result.list?.[0];
  return row ? Number(row.markPrice) : null;
}
