# LightPool Tutorials

Step-by-step tutorials for building apps on LightPool.

**If you are an AI agent:** read [`AGENTS.md`](AGENTS.md) first, then [`common/glossary.md`](common/glossary.md) and [`common/architecture.md`](common/architecture.md). Do not invent clob-index fields; use [`skills/spot-lightpool/`](skills/spot-lightpool/).

## Tutorials

- Event contract app — start at [`event-contract/chapter1-run-local/README.md`](event-contract/chapter1-run-local/README.md)
- Tokenized stocks — eight chapters. Step list: [`tokenized-stocks/tokenized-stocks-video-by-chapter.md`](tokenized-stocks/tokenized-stocks-video-by-chapter.md)

| Chapter | What you do |
|---------|-------------|
| [1 Run local](tokenized-stocks/chapter1-run-local/README.md) | Install tools, download repos, start the local stack |
| [2 Scaffold app](tokenized-stocks/chapter2-scaffold-app/README.md) | Create `tokenized-stocks-app` (frontend + thin backend) |
| [3 Rough UI shell](tokenized-stocks/chapter3-rough-ui-shell/README.md) | Full trade layout with placeholders only |
| [4 Admin](tokenized-stocks/chapter4-admin/README.md) | Create USDT and stock markets; wire the markets list |
| [5 Chart bars](tokenized-stocks/chapter5-chart-bars/README.md) | OHLC chart for the selected market |
| [6 Liquidity making](tokenized-stocks/chapter6-liquidity-making/README.md) | Maker bot, then the order book UI |
| [7 Deposit / withdraw](tokenized-stocks/chapter7-deposit-withdraw/README.md) | Move funds in and out; show balances |
| [8 Order ticket](tokenized-stocks/chapter8-order-ticket/README.md) | Ticket UI, then place orders and live history |

## Agent pack (this repo)

| Path | Purpose |
|------|---------|
| [`AGENTS.md`](AGENTS.md) | Read order, hard rules, chapter 1 verify |
| [`scripts/run-venue.sh`](scripts/run-venue.sh) | Start local node + clob-indexer |
| [`common/glossary.md`](common/glossary.md) | Types, ports, demo keys, repos |
| [`common/architecture.md`](common/architecture.md) | Event-contract vs spot vs bridge |
| [`skills/spot-lightpool/`](skills/spot-lightpool/) | Frozen clob-index HTTP / WS / tx-submit contract |
