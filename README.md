# Risk-Gated Bybit Perpetuals Trading Bot

GPT-6 Astra analyzes Bybit market data and proposes trades. It never touches
the exchange directly — a deterministic risk-gate MCP server, holding the
only trading-permission API key, checks and forwards (or rejects) every
order. Files on disk carry strategy, memory, and audit records between runs.

```text
Strategy + Memory + Scheduler
             |
             v
       GPT-6 Astra
       |           |
       | reads     | proposes writes
       v           v
Official Bybit   Custom risk-gate MCP
MCP market data        |
                       | approved orders only
                       v
                 Bybit Perpetuals
                       |
                       v
             Audit, trades, lessons,
             alerts, and next cycle
```

**Status:** the included EMA 9/21 strategy (`STRATEGY.md`) is a teaching
scaffold for validating this pipeline, not a proven trading edge. Everything
here defaults to Bybit **testnet**. Read the [mainnet readiness
checklist](#mainnet-readiness-checklist) before ever pointing this at real
funds.

## Project layout

```text
trading-bot/
  STRATEGY.md              fixed strategy contract the model must follow literally
  HALT_TRADING              kill switch — exists only while trading is halted
  prompts/cycle.md          the 8-step operating cycle given to the model
  memory/
    trades.jsonl             one closed trade per line
    learnings.md              capped, running list of lessons
    decision.json             the latest cycle's decision, written before any order
  risk-gate/                deterministic MCP server, TypeScript
    src/{index,checks,bybit,audit,paths,types}.ts
    src/checks.test.ts        unit tests for every rejection path
    dist/                     build output (gitignored)
  scripts/
    position-check.js         cron, every minute — read-only position diff/alerts
    funding-check.js          cron, every 4h — read-only funding-rate alerts
    telegram-alert.js         CLI: node scripts/telegram-alert.js "text"
    telegram-commands.js      long-running: /status /halt /resume /close /why
    lib/                      shared path/Bybit-read/Telegram helpers
  logs/
    audit.jsonl                every risk-gate request, check result, and outcome
    cycle.log, position.log, funding.log   cron output (gitignored)
  crontab.txt                the three scheduled jobs
  .env.example                documents required environment variables
```

## 1. Prerequisites

* Codex CLI 0.153.1+ with access to `gpt-6-astra`
* Node 20.6+
* A **separate** Bybit testnet account and testnet API key
* A machine that stays awake (for cron + the Telegram listener)
* Optional: a Telegram bot token, for alerts and `/halt` `/resume` `/close` `/why`

```bash
node --version
codex --version
which npx
```

## 2. Install

```bash
npm run install:gate   # installs risk-gate/node_modules
npm install             # installs the project root's deps (Telegram-commands' MCP client)
npm run build:gate      # compiles risk-gate/src -> risk-gate/dist
npm run test:gate       # runs risk-gate/src/checks.test.ts
```

## 3. Configure Codex

Add the official Bybit MCP for market-data reads:

```bash
codex mcp add bybit -- npx -y bybit-official-trading-server@latest
```

Then edit `~/.codex/config.toml` (outside this repo — never commit
credentials or this file into the project):

```toml
model = "gpt-6-astra"
model_reasoning_effort = "high"

[mcp_servers.bybit]
command = "npx"
args = ["-y", "bybit-official-trading-server@latest"]
env = { BYBIT_TESTNET = "true" }

[mcp_servers.risk-gate]
command = "node"
args = ["/absolute/path/to/trading-bot/risk-gate/dist/index.js"]
env = { BYBIT_TESTNET = "true", BYBIT_API_KEY = "...", BYBIT_API_SECRET = "..." }
```

Replace the path and credentials. **The model must never be given a Bybit
MCP configuration that includes a trading-permission key** — only
`risk-gate` should hold one. Restart Codex after editing the config; MCP
servers connect at session start.

## 4. Create a Bybit testnet API key

1. Create a **testnet** account (separate from mainnet) at Bybit's testnet
   site and fund it with test USDT from the faucet.
2. Create an API key scoped to **contract trading** permission only — no
   withdrawal permission.
3. Use this key only for `BYBIT_API_KEY` / `BYBIT_API_SECRET` in the
   risk-gate's `env` block above.
4. Optionally create a **second**, read-only key for
   `scripts/position-check.js`, `scripts/funding-check.js`, and
   `telegram-commands.js`'s `/status` — see `.env.example`. This keeps the
   only trading-permission credential confined to the risk gate.

A mainnet key never authenticates against `https://api-testnet.bybit.com`,
so there is no risk of accidentally trading real funds while
`BYBIT_TESTNET=true`.

## 5. Configure Telegram (optional but recommended)

1. Create a bot with [@BotFather](https://t.me/BotFather), get its token.
2. Message the bot once, then call
   `https://api.telegram.org/bot<token>/getUpdates` to find your chat id.
3. Export `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` in the environment
   used to run `scripts/*.js` (see `.env.example`). `telegram-commands.js`
   only acts on commands from that exact chat id.

## 6. Run a manual test cycle

Before touching cron, run one cycle by hand and inspect everything it
produced:

```bash
codex exec "$(cat prompts/cycle.md)"

cat memory/decision.json
tail logs/audit.jsonl
```

Confirm:
* `memory/decision.json` reflects a decision consistent with `STRATEGY.md`.
* If an order was proposed, `logs/audit.jsonl` has one entry per check plus
  the final `approved`/`rejected` outcome, and (if approved) the exchange
  response.
* On Bybit's testnet UI, any approved order actually appears with its
  attached stop loss / take profit.

## 7. Kill switch

```bash
touch HALT_TRADING      # stop every write immediately, no restart needed
rm HALT_TRADING          # resume
```

The risk gate checks for this file on **every** tool call — `place_order`,
`close_position`, `set_leverage`, and `cancel_order` all refuse while it
exists. This is a full stop, not just an entry filter: verify with a
controlled test that `close_position` is also rejected while halted.

## 8. Install cron

Edit the absolute path in `crontab.txt`, then:

```bash
crontab crontab.txt
```

Only enable cron **after** step 6 behaves correctly. Start
`scripts/telegram-commands.js` separately (it long-polls continuously and
is not a cron job) under systemd, pm2, or a persistent tmux session:

```bash
node scripts/telegram-commands.js
```

## 9. Validate every risk-gate rejection path

Before trusting the gate, trigger each rejection deliberately (e.g. by
calling its tools with a Codex or MCP inspector session, or by editing test
fixtures) and confirm the request is rejected and logged:

* `HALT_TRADING` present → every tool rejects with `kill_switch`.
* Simulated daily loss beyond 5% of equity → new entries rejected with
  `daily_loss_cap`; `close_position` still succeeds.
* An order notional above 30% of equity → `notional_cap`.
* Leverage above 10x (BTC) or 5x (ETH/SOL) → `leverage_cap`.
* A limit price more than 2% from mark → `price_sanity`.
* A 4th open position, or a 2nd entry on a symbol already open →
  `position_cap`.

`risk-gate/src/checks.test.ts` already exercises all of these
deterministically against a fake Bybit client — `npm run test:gate` is the
fast way to re-verify the logic itself; the manual pass above verifies the
real wiring (paths, env, the exchange).

## 10. Operate on testnet for at least two weeks

Review `logs/audit.jsonl`, `memory/trades.jsonl`, and `memory/learnings.md`
daily. Confirm learnings only ever *inform* reasoning — check that
`STRATEGY.md`'s rules are never silently relaxed.

## Mainnet readiness checklist

Do not switch `BYBIT_TESTNET` to `false` until every item is true:

- [ ] The testnet system has run cleanly for at least two weeks.
- [ ] The model cannot access any direct order-placement tool (the Bybit
      MCP config holds no trading-permission key).
- [ ] Every write appears in `logs/audit.jsonl`.
- [ ] The kill switch rejects entries — and closures — immediately.
- [ ] Gate rejections are never retried with modified values (spot-check
      `logs/cycle.log` after a rejection).
- [ ] Daily loss limits still permit risk-reducing closures.
- [ ] Attached stop loss and take profit orders appear correctly on Bybit.
- [ ] Telegram `/halt`, `/resume`, `/status`, `/close`, `/why` all work.
- [ ] The mainnet key has trading permission only — no withdrawal access.
- [ ] An IP allowlist is enabled on the mainnet key.
- [ ] Credentials exist only in `~/.codex/config.toml`'s env block / your
      process manager's environment — never in a file inside this project.
- [ ] The initial mainnet position size is the smallest size the gate's
      30% notional cap allows.

The system's central safety property: **the model may reason and propose,
but deterministic code in `risk-gate/` controls whether any order ever
reaches the exchange.**
