---
tags: [project, trading, high-risk]
updated: 2026-10-06
---
# Bybit Trading Bot

A risk-gated Bybit perpetuals bot. An AI model proposes trades; a deterministic **risk-gate MCP server**
(the only holder of the trading API key) checks every order and forwards or rejects it. Files on disk carry strategy,
memory (`memory/decision.json`, `learnings.md`, `trades.jsonl`) and audit logs between runs.

- **Code:** branch `claude/bybit-trading-bot-risk-gate-r7apfr` (`risk-gate/`, `scripts/`, `prompts/cycle.md`, `STRATEGY.md`).
- **State:** scaffold added 2026-09-21. 2026-10-03: risk gate hardened to fail closed on bad inputs/exchange
  data (`84b1ec0`, local only, tests not run — no Node on the PC). 2026-10-06: the Bybit client itself now
  throws on missing/blank exchange numbers (`b9e9225`, local only, not run).

## Hard rules for every agent
- Never weaken, bypass or disable the risk gate's checks.
- Never place live orders, change position limits or add API keys without the owner's explicit, written go-ahead in that session.
- Never commit secrets. Keys stay in `.env` (git-ignored).

## Tasks
- [ ] **owner:** confirm status (paper trading? live?) and what's next
- [x] **app-engineer:** risk gate `input_sanity` check (fail closed on 0/NaN mark, equity, leverage, qty, price) — `84b1ec0`, 2026-10-03
- [ ] **app-engineer / anyone with Node:** run `npm test` and `npx tsc --noEmit` in `risk-gate/` to confirm `84b1ec0` (18 tests) and `b9e9225` (`bybit.test.ts`). Also check the test script's `src/**/*.test.ts` glob really picks up files directly in `src/` (plain `sh` has no `**`; Node 22's `--test` glob may cover it).
- [x] **app-engineer:** `bybit.ts` throws instead of returning 0/NaN for a missing wallet list, blank equity/leverage/size/mark price/closed PnL (`parseExchangeNumber`); size-0 rows still skipped; `closePosition` only needs side+size so a blank leverage can't block a close — `b9e9225`, 2026-10-06, not run (no Node)
