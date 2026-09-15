# Tokenized stocks — Chapter 3: Rough UI for all parts

**Goal:** Build the full Hyperliquid-style trade shell on `tokenized-stocks-app` with **placeholders only** (no real clob-index data yet).

**Prerequisite:** Chapter 2 scaffold (`tokenized-stocks-app` exists).

**Agents:** read [`../../AGENTS.md`](../../AGENTS.md) and the Rough layout in [`../tokenized-stocks-video-by-chapter.md`](../tokenized-stocks-video-by-chapter.md). Detailed instructions: [`../../prompts/tokenized-stocks-app-03-rough-ui-shell.txt`](../../prompts/tokenized-stocks-app-03-rough-ui-shell.txt). Study the trade-page geometry at [Hyperliquid HYPE/USDC](https://app.hyperliquid.xyz/trade/HYPE/USDC).

## Prompt (copy to your AI)

```text
Please read lightpool-tutorials/prompts/tokenized-stocks-app-03-rough-ui-shell.txt, and please read https://app.hyperliquid.xyz/trade/HYPE/USDC. Please help me create Rough UI for all parts on tokenized-stocks-app. It should have connect, market list, bars, orderbook and recent trades, Order ticket buy/sell, deposit/withdraw, and Balances | Open orders | History | Fills.
```

## Layout reminder

```text
bars | order book (with trades) | order ticket (buy/sell + deposit/withdraw)
bottom tabs only to the right edge of the order book
```

## Verify

- Open `http://127.0.0.1:3000` — all panels visible as placeholders
- Top bar has wallet / connect; Admin page reachable
- Bottom tabs: Balances | Open orders | History | Fills (do not sit under the order ticket)
- No requirement that clob-index is up for the shell to render
