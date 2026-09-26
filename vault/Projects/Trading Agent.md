---
tags: [project, trading]
status: needs documenting
updated: 2026-09-26
---
# Trading Agent (forex setups)

> Written from Routine and session records on 2026-09-26; **not yet checked against the code**. The first hourly run
> fills this in from the repo's README (see [[Work Queue]]).

- **Code:** separate repo `j77jznh99s-cell/trading-agent`, branch `claude/hourly-project-processing-ejbqs4`.
- **What it does (from the Routine):** scans the 28 major forex pairs for candlestick trend setups and suggests them
  for the owner to **review and place themselves**. It never places, modifies or closes anything.
  Command: `python3 -m trading_agent.cli signals --pairs all --new-only --html` (`--source oanda` for real candlesticks).
- **Daily alert:** Routine "Forex setups: daily alert (review only)", weekdays 15:30 UTC, sends a push notification and
  updates the Trading Agent page: https://claude.ai/artifact/2B7XPapVPMvRtFYaYx2gvV
- **Blocked:** OANDA setup (network access + `OANDA_ENV`, `OANDA_ACCOUNT_ID`), waiting on the owner. Without it,
  prices come from api.frankfurter.dev and the rule is untested on real prices.
- **Rules:** same as the Bybit bot: never trade, never weaken a risk gate, account data stays under `private/` (git-ignored).

## Tasks
- [ ] **knowledge-keeper:** fill in this note from the repo README.
- [ ] **owner:** OANDA setup (above).
