# Strategy: EMA 9/21 trend follow, 4h

## Status
This is a teaching scaffold for validating the trading pipeline. It is **not** a
proven trading edge and carries no promise of profit. Run it on Bybit testnet
for at least two weeks before ever considering mainnet.

## Pairs
BTCUSDT, ETHUSDT, SOLUSDT
Category: linear

## Timeframe
Decide on the 4h close. Manage positions on 15m.

## Entry
Long: 9 EMA crosses above 21 EMA on the 4h close, price is above the 200 EMA,
and funding is below 0.03% per 8h.

Short: mirror the long rules (9 EMA crosses below 21 EMA, price below the
200 EMA, funding above -0.03% per 8h).

Do not enter if a position is already open on that symbol.

## Exit
Stop: 1.5 times ATR(14) from entry.
Take profit: 3R, or a 9/21 cross back, whichever occurs first.
Time stop: close if the position is flat after 5 days.

## Sizing
Risk 1% of equity per trade.

```
qty = (equity * 0.01) / stop_distance
```

Leverage: BTC 5x, ETH and SOL 3x.

Never exceed the risk gate limits (10x BTC / 5x ETH,SOL leverage cap, 30%
equity notional cap, 3 open positions max). The risk gate enforces these
independently of this document; this document must stay inside those limits
by construction.

## Execution
Use market entries only.
Attach take profit and stop loss to the entry order.

## Rule discipline
These rules are a fixed contract for the trading cycle. Lessons recorded in
`memory/learnings.md` may inform reasoning and confidence, but they must
never silently relax, replace, or add exceptions to the rules above. If a
lesson conflicts with this document, the document wins and the conflict
should be written up for a human to resolve, not resolved automatically.
