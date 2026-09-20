# Tokenized stocks — beginner develop steps (from the ground)

Goal: help a beginner **build** a tokenized-stocks exchange app on LightPool.

Study a full trade screen like [Hyperliquid Trade](https://app.hyperliquid.xyz/trade): one page, many panels.  
**First** ship a rough UI with **every** panel as empty boxes.  
**Then** implement panels one by one.

Sample app: `tokenized-stocks-app`.  
This file lives in `lightpool-tutorials/tokenized-stocks/`.

---

## What the finished trade page looks like (spot)

Rough layout (same idea as Hyperliquid trade):

```text
┌────────────────────────────────────────────────────────────┬──────────────────┐
│ Top bar: logo | Trade | Admin | wallet / connect           │                  │
├──────────┬──────────────────────┬──────────────────────────┤  Order ticket    │
│ Markets  │  Chart (bars)        │  Order book              │  buy / sell      │
│ list     │                      │  + recent trades         │                  │
│          │                      │                          │  Deposit /       │
│          │                      │                          │  Withdraw        │
├──────────┴──────────────────────┴──────────────────────────┤                  │
│ Bottom tabs: Balances | Open orders | Order history | Trade history │                  │
└────────────────────────────────────────────────────────────┴──────────────────┘
```

Left-to-right main row: **bars | order book (with trades) | order ticket**.  
Order ticket is a **full-height right column** (buy/sell, then Deposit / Withdraw under it).  
Bottom tabs only span to the **right edge of the order book**; they do **not** sit under the order ticket.

Off the main trade page (still in the app):

- **Admin** page (create token, create market, mint/fund)
- **Liquidity maker** (bot process / ops page — not a trader widget)

---

## Beginner step list

| Step | Name | What you do | 做什么 |
|------|------|-------------|--------|
| 1 | Run local venue | Start LightPool node + clob-index. App will only talk to clob-index (`:3002`). | 启动 LightPool 节点 + clob-index。应用只对接 clob-index（`:3002`）。 |
| 2 | Scaffold app | Create `tokenized-stocks-app` (frontend + thin backend). | 创建 `tokenized-stocks-app`（前端 + 薄后端）。 |
| 3 | Rough UI for **all** parts | Build the full trade layout above with **placeholders only** (labels, empty tables, fake market name). No real API yet. Deposit / Withdraw is a placeholder under the order ticket; Admin is a separate empty page. User can click around the shell. | 按上方完整交易页布局搭好**占位壳**（标签、空表、假市场名）。先不接真实 API。Deposit / Withdraw 在下单区下方占位；Admin 为独立空页。用户可点击浏览整页壳。 |
| 4 | Admin (+ markets list) | Create USDT + stock token, create spot market, fund accounts; wire markets list to load pairs and select spot `ContractAddress`. | 创建 USDT + 股票代币、创建现货市场、给账户打款；打通市场列表，加载交易对并选中现货 `ContractAddress`。 |
| 5 | Chart (bars) | OHLC into TradingView (or simple candles) for selected market. | 为当前选中市场接入 OHLC（TradingView 或简单 K 线）。 |
| 6 | Liquidity making (+ order book) | Run a maker bot so the book has size; wire order book UI (bids/asks + live updates; optional recent trades). | 跑做市 bot 让盘口有量；接通订单簿 UI（买卖盘 + 实时更新；可选近期成交）。 |
| 7 | Deposit / withdraw | Move funds in/out so the user can pay for orders, and show that user's balances in the bottom tabs. | 资金出入，以便用户能下单支付，并在底部状态区显示该用户余额。 |
| 8 | Order ticket | First reshape the ticket UI (8a). Then Enable trading + place Limit/Market and live Open orders / Order history / Trade history (8b). | 先改下单区 UI（8a）。再 Enable trading、下单，并接通 Open orders / Order history / Trade history（8b）。 |

---

## Order rule

1. **Shell first** (step 3) — every block visible, none finished.  
2. **Then one step at a time** (steps 4–8).  
3. **Deposit / withdraw before order ticket** — otherwise the user cannot fund to place.

---

## Suggested tutorial / video chapters

| Step | Chapter folder |
|------|----------------|
| 1 | `chapter1-run-local/` |
| 2 | `chapter2-scaffold-app/` |
| 3 | `chapter3-rough-ui-shell/` |
| 4 | `chapter4-admin/` |
| 5 | `chapter5-chart-bars/` |
| 6 | `chapter6-liquidity-making/` |
| 7 | `chapter7-deposit-withdraw/` |
| 8 | `chapter8-order-ticket/` |
