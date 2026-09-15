# Scripts

Shared helpers for LightPool tutorials.

| Script | Purpose |
|--------|---------|
| [`run-venue.sh`](run-venue.sh) | Start / stop local **lightpool** validator + **clob-indexer** only |

```bash
# from lightpool-tutorials/
./scripts/run-venue.sh start
./scripts/run-venue.sh status
./scripts/run-venue.sh stop
./scripts/run-venue.sh clean
```

Default data dir: `$LABS/data/tokenized-stocks`.
Requires built binaries: `lightpool-node/bin/lightpool` and `lightpool-clob-indexer` (or `lightpool-clob-indexer/target/release/lightpool-clob-indexer`).

`clean` only deletes the data directory. If services are still up, stop first:

```bash
./scripts/run-venue.sh stop
./scripts/run-venue.sh clean
```