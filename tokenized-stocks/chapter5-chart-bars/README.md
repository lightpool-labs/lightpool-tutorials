# Tokenized stocks — Chapter 5: Chart (bars)

**Goal:** Show OHLC for the selected LightPool spot market using **TradingView Lightweight Charts**. Load **Hyperliquid history first**, then **subscribe** for new bars. LightPool base `AAPL` → Hyperliquid coin **`xyz:AAPL`** (fixed `xyz:` prefix; see [xyz:AAPL trade UI](https://app.hyperliquid.xyz/trade/xyz:AAPL)). No per-market coin field. US equities only.

**Prerequisite:** Chapter 4 Admin + markets list; venue running.

**Agents:** detailed instructions in [`../../prompts/tokenized-stocks-app-05-chart-bars.txt`](../../prompts/tokenized-stocks-app-05-chart-bars.txt).

**Layout reference:** [`../tokenized-stocks-video-by-chapter.md`](../tokenized-stocks-video-by-chapter.md) (step 5).

## Prompt (copy to your AI)

```text
Please read lightpool-tutorials/prompts/tokenized-stocks-app-05-chart-bars.txt. Help me implement Chart (bars) on tokenized-stocks-app. For the selected US equity spot market (e.g. AAPL), load Hyperliquid candle history for coin xyz:AAPL first, then subscribe for live bars. Display with TradingView Lightweight Charts. Use fixed rule xyz:<SYMBOL>; No crypto ticker examples.
```

## Verify

- Select `AAPL/USDT` → history/live for **`xyz:AAPL`** (not bare `AAPL`)
- Switch to `TSLA/USDT` → **`xyz:TSLA`**
- Browser only talks to app backend for bars
