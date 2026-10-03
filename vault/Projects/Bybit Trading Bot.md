---
tags: [project, trading, high-risk]
updated: 2026-09-23
---
# Bybit Trading Bot

A risk-gated Bybit perpetuals bot. An AI model proposes trades; a deterministic **risk-gate MCP server**
(the only holder of the trading API key) checks every order and forwards or rejects it. Files on disk carry strategy,
memory (`memory/decision.json`, `learnings.md`, `trades.jsonl`) and audit logs between runs.

- **Code:** branch `claude/bybit-trading-bot-risk-gate-r7apfr` (`risk-gate/`, `scripts/`, `prompts/cycle.md`, `STRATEGY.md`).
- **State:** scaffold added 2026-09-21. 2026-10-03: risk gate hardened to fail closed on bad inputs/exchange
  data (`84b1ec0`, local only, tests not run — no Node on the PC).

## Hard rules for every agent
- Never weaken, bypass or disable the risk gate's checks.
- Never place live orders, change position limits or add API keys without the owner's explicit, written go-ahead in that session.
- Never commit secrets. Keys stay in `.env` (git-ignored).

## Tasks
- [ ] **owner:** confirm status (paper trading? live?) and what's next
- [x] **app-engineer:** risk gate `input_sanity` check (fail closed on 0/NaN mark, equity, leverage, qty, price) — `84b1ec0`, 2026-10-03
- [ ] **app-engineer / anyone with Node:** run `npm test` and `npx tsc --noEmit` in `risk-gate/` to confirm `84b1ec0` (18 new tests)
- [ ] **app-engineer:** make `bybit.ts` throw instead of returning 0 for a missing wallet list (`?? "0"`) or empty leverage/size strings (the gate now catches these, but the client still produces them)
