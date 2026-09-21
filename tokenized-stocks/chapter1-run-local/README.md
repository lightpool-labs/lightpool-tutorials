# Tokenized stocks — Chapter 1: run local

```bash
mkdir -p lightpool-labs && cd lightpool-labs
git clone git@github.com:lightpool-labs/lightpool-tutorials.git
```

## Step 1

Install the toolchain. Copy this to your AI:

```text
Please read lightpool-tutorials/prompts/tokenized-stocks-01-install-tools.txt. Install Rust, Node.js, Foundry, Python 3, git, and curl if they are missing. Skip tools that are already installed. Print each version when done. Do not clone repositories and do not start any service.
```

## Step 2

Download the other repositories and build them. Repositories that are already cloned are skipped.

```bash
cd lightpool-tutorials
./scripts/bootstrap-stocks.sh
```

The script clones these repositories under `lightpool-labs`: `lightpool-node`, `lightpool-crypto`, `lightpool-sdk-rust`, `lightpool-clob-indexer`, `lightpool-bridge`, `lightpool-bot`, and `tokenized-stocks-app`. It then downloads Reth and builds the node, indexer, bridge, maker, and app backend.

## Step 3

Start the local stack (Reth, LightPool, indexer, tokens and spot markets, bridge, maker, and the app).

```bash
./scripts/start-stocks-07.sh start
```

Open http://127.0.0.1:3000

Stop:

```bash
./scripts/start-stocks-07.sh stop
```

Delete runtime data (stop first):

```bash
./scripts/start-stocks-07.sh clean
```
