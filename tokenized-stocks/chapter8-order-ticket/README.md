# Tokenized stocks — Chapter 8: Order ticket

Step 8 has **two AI prompts**. Recommended order: **8a then 8b**.

| Prompt | File | Repo | Purpose |
|--------|------|------|---------|
| **8a** | [`../../prompts/tokenized-stocks-app-08a-order-ticket-ui.txt`](../../prompts/tokenized-stocks-app-08a-order-ticket-ui.txt) | `tokenized-stocks-app` | Reshape ticket + user-state tabs; Deposit / Withdraw dialog; no place yet |
| **8b** | [`../../prompts/tokenized-stocks-app-08b-enable-trading.txt`](../../prompts/tokenized-stocks-app-08b-enable-trading.txt) | `tokenized-stocks-app` | Enable trading, place Limit/Market, live Open orders / Order history / Trade history |

Reference look: [Hyperliquid Trade HYPE/USDC](https://app.hyperliquid.xyz/trade/HYPE/USDC) (layout only; product stays AAPL/TSLA/INTC).

**Layout reference:** [`../tokenized-stocks-video-by-chapter.md`](../tokenized-stocks-video-by-chapter.md) (step 8).

**Prerequisite:** Chapter 7 done. From `lightpool-tutorials/`:

```bash
./scripts/start-stocks-07.sh
```

## Prompt 8a — Order ticket UI (copy to your AI)

```text
Please read lightpool-tutorials/prompts/tokenized-stocks-app-08a-order-ticket-ui.txt. On tokenized-stocks-app, reshape the order ticket toward Hyperliquid-style Market/Limit tabs: available balance under Buy/Sell, size with a percentage slider, Enable/submit button at the bottom (disabled). Deposit and Withdraw open a dialog for token and amount. Hide zero-balance rows in Balances. Rename bottom tabs History → Order history and Fills → Trade history (empty placeholders with correct columns). Align the divider above Deposit/Withdraw with the divider above Balances. Do not place or cancel orders in this step.
```

## Prompt 8b — Enable trading + live tabs (copy to your AI)

```text
Please read lightpool-tutorials/prompts/tokenized-stocks-app-08b-enable-trading.txt and lightpool-tutorials/skills/spot-lightpool/tx-submit.md, http.md, and ws.md. On tokenized-stocks-app after 8a: wire Enable trading (reuse chapter 7 set_agent if needed), then place Limit/Market orders. Fill Open orders, Order history, and Trade history with GET /api/orders plus WS channel user. Prefer agent signing after enable so MetaMask is not required on every order. Do not require event-contract-app.
```

## Verify

Prerequisite: `./scripts/start-stocks-07.sh` has finished; Connect works; the demo user has some LightPool USDT. Maker book has size for fills.

**8a**

1. Order ticket shows Market / Limit, Buy / Sell, available balance, size + percentage scale, and a disabled bottom action button.
2. Deposit / Withdraw open a dialog (token + amount).
3. Balances lists only non-zero assets.
4. Bottom tabs include **Order history** and **Trade history**.
5. The line above Deposit / Withdraw continues into the line above Balances.

**8b**

1. **Enable trading** authorizes the agent; the button becomes Buy/Sell.
2. A Limit (or Market) order appears under **Open orders** (or completes into history/fills if matched).
3. **Trade history** shows fills; **Order history** shows past orders; open rows stay only under Open orders.
4. Balances update after trading.
