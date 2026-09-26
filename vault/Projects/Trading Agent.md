---
tags: [project, trading]
status: documented, blocked on owner (OANDA)
updated: 2026-09-26
---
# Trading Agent (forex setups)

> Filled in from the repo's `README.md` and `CHANGELOG.md` on 2026-09-26 (hourly run). Read-only research; this
> agent never places, modifies or closes a trade — there is no code path that does.

- **Code:** separate repo `j77jznh99s-cell/trading-agent`, branch `claude/hourly-project-processing-ejbqs4`.
- **What it is:** a research toolkit for testing trading ideas on historical data — backtests plus a paper broker.
  **Simulation only.** Strategies: `sma` (crossover), `rsi` (mean reversion), `breakout` (Donchian), `buy_and_hold`.

## How to run it
```bash
pip install -e '.[dev]'
trading-agent backtest --synthetic          # seeded fake prices, no download
trading-agent backtest --csv SPY.csv --html reports/spy.html
pytest                                       # 191 tests; CI runs Python 3.10/3.12/3.13 + ruff lint
```
- `fetch TICKER...` downloads free daily prices from Stooq (cached 12h) into `data/prices/`.
- `daily --ticker SPY` does the full loop: fetch → advance paper account → write `reports/daily.html`. A GitHub
  Actions workflow (`.github/workflows/daily-paper.yml`) runs this, **manual trigger only** until its `schedule`
  line is uncommented.
- Full checkup: `research --csv FILE` runs every check (walk-forward, sensitivity, Monte Carlo, regimes, cost
  stress) and writes a pass/warn/fail index page.
- Owner's own forex account, read-only (needs `OANDA_API_TOKEN` + `OANDA_ACCOUNT_ID`): `oanda-account` (balance,
  open trades, **NO STOP** warnings), `history --oanda-api --html` (real closed trades, win rate to break even).
- Live-alert command: `signals --pairs all --new-only --html` (`--source oanda` for real candlesticks) — scans the
  28 major pairs and prints setups for the owner to review and place **themselves**.
- Risk controls available to any strategy/backtest: `--max-position`, `--stop-loss`, `--trailing-stop`,
  `--vol-target`, `--min-hold-days`, `--max-entries-per-month`, and a `--max-dd-halt` kill switch.

## Daily alert (already wired up)
Routine "Forex setups: daily alert (review only)", weekdays 15:30 UTC — sends a push notification and updates the
Trading Agent artifact page: https://claude.ai/artifact/2B7XPapVPMvRtFYaYx2gvV

## Tests / quality (from CHANGELOG, not re-run by this session)
191 tests; CI runs Python 3.10, 3.12, 3.13 plus a ruff lint step. `examples/quickstart.sh` runs every command
end-to-end on synthetic data and CI runs it on each push.

## Blocked
OANDA setup (network access to `api-fxpractice.oanda.com` / `api-fxtrade.oanda.com`, plus env vars `OANDA_ENV` and
`OANDA_ACCOUNT_ID`), waiting on the owner. Without it, `signals` falls back to free ECB rates via Frankfurter, and
the rule is untested on real prices. Account exports (`history --oanda-csv`, `--fidelity-csv`) and any report with
the owner's own figures are written under `private/`, which is git-ignored.

## Rules
Same as the Bybit bot: never trade, never weaken a risk gate, account data stays under `private/`. Read-only
GitHub access only from this session (no pushes).

## Tasks
- [x] **knowledge-keeper:** fill in this note from the repo README/CHANGELOG (2026-09-26).
- [ ] **owner:** OANDA setup (above) — blocks real-price testing of the forex rule and the owner's own account
      commands (`oanda-account`, `history --oanda-api`).
- [ ] **owner:** decide whether to enable the `daily-paper.yml` GitHub Actions schedule (currently manual-only).
