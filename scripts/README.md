# Scripts

Shared helpers for LightPool tutorials.

| Script | Purpose |
|--------|---------|
| [`run-venue.sh`](run-venue.sh) | Start / stop local **lightpool** validator + **clob-indexer** only |
| [`bootstrap-stocks.sh`](bootstrap-stocks.sh) | Clone tokenized-stocks sibling repos and build release binaries |
| [`start-stocks-07.sh`](start-stocks-07.sh) | Start / stop the local stock stack (Reth, node, indexer, bridge, maker, app) |
| [`fund-maker.sh`](fund-maker.sh) | Mint **USDT** + **AAPL/TSLA/INTC** to the maker wallet (Anvil #0) |

```bash
# from lightpool-tutorials/
./scripts/run-venue.sh start
./scripts/run-venue.sh status
./scripts/run-venue.sh stop
./scripts/run-venue.sh clean

# After Admin created USDT + equity markets:
./scripts/fund-maker.sh
```

Default data dir: `$LABS/data/tokenized-stocks`.
Requires built binaries: `lightpool-node/bin/lightpool` and `lightpool-clob-indexer` (or `lightpool-clob-indexer/target/release/lightpool-clob-indexer`).

`fund-maker.sh` loads token addresses from `http://127.0.0.1:3001/api` (fallback: `$LABS/data/tokenized-stocks/registry.json`), then mints so the maker can **buy with USDT** and **sell AAPL/TSLA/INTC**. Defaults: **10B USDT**, **1B** per equity (override with `USDT_AMOUNT` / `STOCK_AMOUNT`).

`clean` deletes `$LABS/data/tokenized-stocks` (venue + app `registry.json` and all course runtime data). If services are still up, stop first:

```bash
./scripts/run-venue.sh stop
./scripts/run-venue.sh clean
```
