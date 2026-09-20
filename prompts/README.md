# Prompts

Copy-paste prompts for AI agents building on LightPool.

Read [`../AGENTS.md`](../AGENTS.md) first.

Step numbers match `tokenized-stocks/tokenized-stocks-video-by-chapter.md` (step 1 = run local — no prompt file yet).

| File | Step | Purpose |
|------|------|---------|
| [`tokenized-stocks-app-02-scaffold.txt`](tokenized-stocks-app-02-scaffold.txt) | 2 Scaffold app | Create `tokenized-stocks-app` (frontend + thin backend) |
| [`tokenized-stocks-app-03-rough-ui-shell.txt`](tokenized-stocks-app-03-rough-ui-shell.txt) | 3 Rough UI | Full trade layout placeholders (Hyperliquid-style shell) |
| [`tokenized-stocks-app-04-admin.txt`](tokenized-stocks-app-04-admin.txt) | 4 Admin (+ markets) | USDT cash + stock token/market; markets list |
| [`tokenized-stocks-app-05-chart-bars.txt`](tokenized-stocks-app-05-chart-bars.txt) | 5 Chart (bars) | HL history + subscribe; Lightweight Charts |
| [`tokenized-stocks-app-06a-equity-liquidity-maker.txt`](tokenized-stocks-app-06a-equity-liquidity-maker.txt) | 6a Liquidity | `equity-liquidity-maker` in lightpool-bot |
| [`tokenized-stocks-app-06b-orderbook-ui.txt`](tokenized-stocks-app-06b-orderbook-ui.txt) | 6b Order book UI | clob-index snapshot + `orderbook_delta` |
| [`tokenized-stocks-app-07-deposit-withdraw.txt`](tokenized-stocks-app-07-deposit-withdraw.txt) | 7 Deposit / withdraw | Connect creates an agent; ticket Deposit / Withdraw signs in MetaMask |
| [`tokenized-stocks-app-08a-order-ticket-ui.txt`](tokenized-stocks-app-08a-order-ticket-ui.txt) | 8a Order ticket UI | Market/Limit layout, deposit dialog, Order/Trade history tabs; no place/cancel yet |
| [`tokenized-stocks-app-08b-enable-trading.txt`](tokenized-stocks-app-08b-enable-trading.txt) | 8b Enable trading | Place Limit/Market; live Open orders / Order history / Trade history |
