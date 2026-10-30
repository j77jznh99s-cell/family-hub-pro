---
tags: [project, trading, high-risk]
updated: 2026-10-30
---
# Bybit Trading Bot

A risk-gated Bybit perpetuals bot. An AI model proposes trades; a deterministic **risk-gate MCP server**
(the only holder of the trading API key) checks every order and forwards or rejects it. Files on disk carry strategy,
memory (`memory/decision.json`, `learnings.md`, `trades.jsonl`) and audit logs between runs.

- **Code:** branch `claude/bybit-trading-bot-risk-gate-r7apfr` (repo root — `risk-gate/`, `scripts/`,
  `prompts/cycle.md`, `STRATEGY.md`). This branch is an orphan root commit (repo was empty when the scaffold
  was built), so it does **not** contain `vault/`/`CLAUDE.md` — don't expect them there.
- **State (2026-10-30):** full scaffold built, builds clean, 14/14 unit tests pass, dry-run validated against
  a fake exchange client (approval + notional-cap rejection + kill-switch blocking both entries and closes).
  Pushed to origin as `6722583`. **Nothing has touched a real Bybit testnet account yet.** See
  [[Session Log]] (2026-10-30 entry, logged late — the build happened 2026-09-21).

## Hard rules for every agent
- Never weaken, bypass or disable the risk gate's checks.
- Never place live orders, change position limits or add API keys without the owner's explicit, written go-ahead in that session.
- Never commit secrets. Keys stay in `.env` (git-ignored).

## Tasks
- [ ] **owner:** create a Bybit **testnet** account + API key (contract-trading permission only), set it in
  `~/.codex/config.toml`'s `risk-gate` MCP env block (not in the repo), and run one real manual cycle
  (README §6). Nothing further can be verified without this.
- [ ] **owner:** confirm intent — is this headed anywhere near real money eventually, or staying a
  testnet/paper exercise? Decides whether cron + Telegram get enabled at all.
- [ ] once a real manual cycle runs clean: trigger each rejection path live (halt / daily-loss / notional /
  leverage / price / position-cap) before enabling `crontab.txt`.
