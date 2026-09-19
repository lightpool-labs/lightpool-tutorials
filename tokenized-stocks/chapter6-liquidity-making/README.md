# Tokenized stocks — Chapter 6: Liquidity making (+ order book)

Step 6 has **two AI prompts**. Recommended order: **6a then 6b** (book has size before you polish the UI). You may implement 6b first against an empty book.

| Prompt | File | Repo | Purpose |
|--------|------|------|---------|
| **6a** | [`../../prompts/tokenized-stocks-app-06a-equity-liquidity-maker.txt`](../../prompts/tokenized-stocks-app-06a-equity-liquidity-maker.txt) | `lightpool-bot` | `equity-liquidity-maker` — HL `xyz:SYMBOL` → LightPool spot |
| **6b** | [`../../prompts/tokenized-stocks-app-06b-orderbook-ui.txt`](../../prompts/tokenized-stocks-app-06b-orderbook-ui.txt) | `tokenized-stocks-app` | Order book UI — clob-index snapshot + WS delta |

Book UI client contract: [`../../skills/spot-lightpool/orderbook-client.md`](../../skills/spot-lightpool/orderbook-client.md).

**Layout reference:** [`../tokenized-stocks-video-by-chapter.md`](../tokenized-stocks-video-by-chapter.md) (step 6).

## Prompt 6a — Equity liquidity maker (copy to your AI)

```text
Please read lightpool-tutorials/prompts/tokenized-stocks-app-06a-equity-liquidity-maker.txt. In lightpool-bot, add binary equity-liquidity-maker (new strategy; do not break Polymarket liquidity-maker). CLI --symbol takes a comma-separated list such as AAPL,TSLA,INTC; the bot must generate xyz:AAPL, xyz:TSLA, xyz:INTC internally (no HL mapping flag). Subscribe Hyperliquid L2 and mirror orders onto each LightPool spot market. Do not implement the Order book UI in this step.
```

## Prompt 6b — Order book UI (copy to your AI)

```text
Please read lightpool-tutorials/prompts/tokenized-stocks-app-06b-orderbook-ui.txt and lightpool-tutorials/skills/spot-lightpool/orderbook-client.md. Help me implement the Order book UI on tokenized-stocks-app: GET full book from clob-index, then subscribe orderbook_delta. Frontend talks to index :3002 directly. Do not require event-contract-app. Do not implement the liquidity maker in this step.
```

## Verify

Prerequisite: venue + indexer running; Admin has created `AAPL`, `TSLA`, and `INTC` markets.

**Fund maker (USDT to buy, equities to sell):**

```bash
# from lightpool-tutorials/
./scripts/fund-maker.sh
```

**6a — run bot (after implement):**

```bash
cd lightpool-bot
cargo run -p lightpool-strategies --release --bin equity-liquidity-maker -- \
  --symbol AAPL,TSLA,INTC
```

**6a — validate books on clob-index (`:3002`):** open these URLs in the browser (expect JSON with non-empty `bids` and/or `asks`):

- http://127.0.0.1:3002/api/markets/AAPL/book?depth=10
- http://127.0.0.1:3002/api/markets/TSLA/book?depth=10
- http://127.0.0.1:3002/api/markets/INTC/book?depth=10

No `--no-trading` in the sample run.

**6b:** Select a market → browser hits `:3002` `/book` and WS `/api/ws`; switch markets resubscribes.
