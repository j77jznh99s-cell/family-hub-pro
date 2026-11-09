---
tags: [project, trading, new]
status: idea stage, blocked on repo access
updated: 2026-10-30
---
# Crypto Signals (momentum checkpoint system)

> New idea, raised this session. **Not the same project as [[Trading Agent]]** (forex/OANDA
> backtesting toolkit, read-only no-push rule) — explicitly confirmed a separate, unrelated system
> by the owner 2026-10-30. Needs its own repo.

## What it is
A crypto trading-signal system, modeled loosely on "Xvantage"'s checkpoint-meter look:
- Parallel agents that run independently, each outputting UP/DOWN + confidence
- A weighted aggregator that combines them across timeframes
- Pressure metrics showing orderbook reality
- A checkpoint-meter UI matching Xvantage's style

## Planned build order
1. Python data fetcher (Binance API → candles)
2. Python momentum agent (RSI, MACD signals)
3. Python aggregator (combine signals)
4. Node.js API server (single endpoint)
5. React dashboard (checkpoint display)

## Status
- Step 1 (Binance data fetcher) was scaffolded once this session (`BinanceDataFetcher` wrapping
  `/api/v3/klines`, plus a multi-timeframe helper) and parsing-verified against a sample payload —
  but it lived only in the sandbox's local working directory, which does not persist across a
  session/worker restart, so **that code no longer exists** and needs rebuilding.
- Live network calls to `api.binance.com` are blocked by this sandbox's egress policy (403 on
  CONNECT) — fine for local dev/parsing tests, but real candle data needs an environment with open
  egress.

## Blocked
- **Repo:** doesn't exist yet. Owner picked "different project, new repo" over reusing
  `trading-agent`. A repo name was being chosen when the session restarted (candidates discussed:
  `crypto-signals`, `checkpoint-meter`) — **owner still needs to pick/confirm the name**, or just
  say "crypto-signals" is fine.
- **GitHub access:** this session's Claude Code GitHub connector only has `family-hub-pro` in
  scope. Tried: (1) `add_repo` directly on a guessed name — 404/not found; (2) creating the repo via
  the GitHub API (`create_repository`) — failed, 403 "Resource not accessible by integration" (the
  installed GitHub App isn't permissioned to create repos); (3) checking
  `github.com/settings/installations` on the owner's account — Claude isn't listed as an installed
  GitHub App there at all (only Railway App is), meaning repo access for this session is actually
  granted through Claude's own connector settings (`claude.ai/customize/connectors`), not GitHub's
  app-installation UI. Owner was mid-way through finding that page when the session restarted.

## Tasks
- [ ] **owner:** confirm the repo name (default: `crypto-signals` if no preference).
- [ ] **owner:** create the repo (or add it under `claude.ai/customize/connectors` → GitHub →
      repository access) so a future session can push to it.
- [ ] once access exists: rebuild `src/data_fetcher.py` (Binance klines wrapper), then continue the
      build order above (momentum agent → aggregator → API server → dashboard).
