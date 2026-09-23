---
tags: [project, trading, high-risk]
updated: 2026-09-23
---
# Bybit Trading Bot

A risk-gated Bybit perpetuals bot. An AI model proposes trades; a deterministic **risk-gate MCP server**
(the only holder of the trading API key) checks every order and forwards or rejects it. Files on disk carry strategy,
memory (`memory/decision.json`, `learnings.md`, `trades.jsonl`) and audit logs between runs.

- **Code:** branch `claude/bybit-trading-bot-risk-gate-r7apfr` (`risk-gate/`, `scripts/`, `prompts/cycle.md`, `STRATEGY.md`).
- **State:** scaffold added 2026-09-21.

## Hard rules for every agent
- Never weaken, bypass or disable the risk gate's checks.
- Never place live orders, change position limits or add API keys without the owner's explicit, written go-ahead in that session.
- Never commit secrets. Keys stay in `.env` (git-ignored).

## Tasks
- [ ] **owner:** confirm status (paper trading? live?) and what's next
