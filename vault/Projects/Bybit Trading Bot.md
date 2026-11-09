---
tags: [project, trading, high-risk]
updated: 2026-10-30
---
# Bybit Trading Bot

A risk-gated Bybit perpetuals bot. An AI model proposes trades; a deterministic **risk-gate MCP server**
(the only holder of the trading API key) checks every order and forwards or rejects it. Files on disk carry strategy,
memory (`memory/decision.json`, `learnings.md`, `trades.jsonl`) and audit logs between runs.

- **Code:** branch `claude/bybit-trading-bot-risk-gate-r7apfr` (`risk-gate/`, `scripts/`, `prompts/cycle.md`, `STRATEGY.md`).
- **State:** scaffold added 2026-09-21. 2026-10-03: risk gate hardened to fail closed on bad inputs/exchange
  data (`84b1ec0`, local only, tests not run — no Node on the PC). 2026-10-06: the Bybit client itself now
  throws on missing/blank exchange numbers (`b9e9225`, local only, not run). 2026-10-06 16:00: the read-only
  monitoring client `scripts/lib/bybit.js` got the same fix (`a9f70ea`, local only, not run). 2026-10-06 20:00:
  `position-check` now tracks hedge-mode legs separately (symbol+side, `47c409d`, local only, not run).
  2026-10-14: all tests run for the first time (Node on the PC) and pass; gate now audits before every exchange
  write and fails closed if it can't (`5c34a45`, local only; gate 69/69, scripts 46/46). 2026-10-15: audit
  entries linked by `attempt_id`; timeouts/network errors report "outcome unknown" not "rejected" (`df80168`, local only; gate 97/97).
- **Cloud note (2026-10-30, merged into this note 2026-11-09):** this branch is an orphan root commit (repo was empty when the scaffold
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
- [ ] **owner:** confirm status (paper trading? live?) and what's next
- [x] **app-engineer:** risk gate `input_sanity` check (fail closed on 0/NaN mark, equity, leverage, qty, price) — `84b1ec0`, 2026-10-03
- [x] **app-engineer / anyone with Node:** run `npm test` and `npx tsc --noEmit` in `risk-gate/` — done 2026-10-14 on the PC (Node 24): 58/58 pass, tsc clean; the glob does pick up files in `src/` on Windows/npm.
- [x] **app-engineer:** `bybit.ts` throws instead of returning 0/NaN for a missing wallet list, blank equity/leverage/size/mark price/closed PnL (`parseExchangeNumber`); size-0 rows still skipped; `closePosition` only needs side+size so a blank leverage can't block a close — `b9e9225`, 2026-10-06, not run (no Node)
- [x] **app-engineer:** monitoring scripts' `scripts/lib/bybit.js` fails closed the same way (missing list throws, so
  `position-check` can't false-alarm "closed" and wipe its snapshot; `""`/`"0"` stop = none; `guessOutcome` no divide-by-0) — `a9f70ea`, 2026-10-06, not run
- [x] **anyone with Node:** `npm run test:scripts` at the repo root — 46/46 pass, 2026-10-14
- [x] **app-engineer:** `position-check` keys positions by symbol+side (hedge-mode legs and one-way side flips now alerted;
  old symbol-keyed snapshots re-keyed on load, no false alerts) — `47c409d`, 2026-10-06 20:00, not run (no Node)
- [x] **app-engineer:** gate writes a `submitting` audit entry before every exchange write (`risk-gate/src/gate.ts`,
  `runGated`); can't write it → new entries/leverage refused, closes/cancels warn and go ahead; a failed final write
  no longer says "exchange rejected it" — `5c34a45`, 2026-10-14, 69/69 gate tests, tsc clean, not pushed
- [x] **app-engineer:** bump `@modelcontextprotocol/sdk` in `risk-gate/` and root to ≥1.30.2 (`npm audit`: high,
  GHSA-6qxp-vccf-f47h, OAuth client; gate uses stdio so probably not exposed) and re-run all tests + tsc —
  `c240454`, 2026-10-18: now ^1.32.1, audit 0, gate 97/97, tsc clean, scripts 46/46; server not started over stdio; not pushed
- [x] **app-engineer:** add a shared id linking each `submitting` audit entry to its `approved`/`error` entry; and
  reword `place_order`'s "exchange rejected it" when the error is a timeout/network failure (order may exist) —
  `df80168`, 2026-10-15 22:04: `attempt_id` + `isUncertainOutcome` ("OUTCOME UNKNOWN, check before resubmitting"); gate 97/97, tsc clean, scripts 46/46; not pushed
- [ ] **owner (optional):** OK that Bybit retCodes 10000 (server timeout) and 10016 (internal error/restarting) now read
  as "outcome unknown" instead of "rejected" (wording only, on the safe side; revert in `gate.ts` `messageLooksUncertain` if not)
- [ ] **qa-tester / owner:** (`test:scripts` now passes) one testnet
  `position-check` run against an old-format `state` snapshot: expect no alerts and a file re-keyed to `symbol:side`
- [x] **app-engineer:** if `position-check` keeps failing (bad data / outage), nothing tells the owner (cron only logs); send one Telegram alert on repeated failures —
  `0ba3a2b`, 2026-10-20 20:03: one alert after 3 failed runs in a row, one on recovery (`failureStep`, counter in `scripts/.state/`); scripts 49/49; real Telegram send not tested; not pushed
- [ ] **owner:** create a Bybit **testnet** account + API key (contract-trading permission only), set it in
  `~/.codex/config.toml`'s `risk-gate` MCP env block (not in the repo), and run one real manual cycle
  (README §6). Nothing further can be verified without this.
- [ ] **owner:** confirm intent — is this headed anywhere near real money eventually, or staying a
  testnet/paper exercise? Decides whether cron + Telegram get enabled at all.
- [ ] once a real manual cycle runs clean: trigger each rejection path live (halt / daily-loss / notional /
  leverage / price / position-cap) before enabling `crontab.txt`.
