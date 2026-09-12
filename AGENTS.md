# LightPool Tutorials — agent instructions

Read this file first. Then read `common/glossary.md` and `common/architecture.md`. Do not scan sibling LightPool repos until a chapter tells you to clone or open a specific path.

This repository is the **AI entry pack** for building apps on LightPool. Runtime code lives in sibling repos that chapters clone. Domain facts and API shapes must come from **this** repo.

LightPool is a self-deployed L1 with an on-chain CLOB (matching and settlement on chain). It is **not** an online SaaS and has **no production**. There is no public LightPool cloud API.

## Tracks

Pick one track. If the user did not say which, ask before acting.

| Track | Product | Start |
|-------|---------|--------|
| Event contract | Prediction-market app (YES/NO books) | [`event-contract/chapter1-run-local/README.md`](event-contract/chapter1-run-local/README.md) |
| Tokenized stocks | Spot exchange (e.g. AAPL/USDT) | [`tokenized-stocks/chapter1-run-local/README.md`](tokenized-stocks/chapter1-run-local/README.md) |

Do not run both tracks in one session unless the user asks.

## Read order

1. This file
2. [`common/glossary.md`](common/glossary.md)
3. [`common/architecture.md`](common/architecture.md)
4. Frozen clob-index API: [`skills/spot-lightpool/SKILL.md`](skills/spot-lightpool/SKILL.md) and the three docs it names
5. The current chapter README only

Do not invent HTTP/WS/tx JSON. Prefer the shapes in `skills/spot-lightpool/`.

## Integration path

```text
App (UI / backend / bot) ──HTTP/WS──► clob-index (:3002) ──► lightpool node
```

- Market data and signed execution go through **clob-index** (`http://127.0.0.1:3002`, `ws://127.0.0.1:3002/api/ws`).
- Do not use node RPC (`:26300`) or node WS (`:26400`) for books, balances, or order submit from an app.
- Sign offline with **lightpool-sdk**; `POST /api/tx/submit` with `{ "tx": SignedTransaction }`.

Event-contract chapter 1 also runs an app backend on `:3001` and UI on `:3000`. That backend is a client of clob-index, not a second chain API.

## Hard rules

- `Address` = user (20-byte `0x…`). `ContractAddress` = token, spot market, or event contract (8-byte module-prefixed `0x…`). Do not mix them.
- Tokens are typically `0x02…`. Spot markets are typically `0x03…`.
- Buy locks **quote**; sell locks **base** in `PlaceOrderParams.token_address`.
- Compare actions via SDK `Name` / `action()`, never raw action strings.
- Demo private keys in this repo are Anvil/Hardhat defaults for local use only.
- Do not modify LightPool node internals, `refs/`, or outdated unit tests to make a tutorial pass.
- If a process fails, read that service’s log under the chapter data dir. Do not restart by guessing new ports.

## What this repo contains vs clones

| In this repo | Clone when a chapter says so |
|--------------|------------------------------|
| Agent docs, glossary, architecture | `lightpool-node` |
| Frozen clob-index API skill | `lightpool-clob-indexer` |
| Chapter prompts and `run-local.sh` | `event-contract-app`, `lightpool-bot`, `lightpool-bridge` (bridge chapters only) |

Sibling repos are for binaries and app source. Do not treat their READMEs as a substitute for `skills/spot-lightpool/`.

## Chapter 1 (event contract, no bridge)

Follow the copy-paste steps in [`event-contract/chapter1-run-local/README.md`](event-contract/chapter1-run-local/README.md) in order: clone → install toolchain → build → `./run-local.sh start`.

That chapter does **not** start Reth or `lightpool-bridge`. Cash is a local `create-token` USDT. Do not add a bridge unless a later chapter says so.

After start, confirm:

- UI `http://127.0.0.1:3000`
- App API `http://127.0.0.1:3001/api`
- clob-index `http://127.0.0.1:3002`
- `GET http://127.0.0.1:3002/api/health/health` → `{ "status": "ok" }`
- Demo user can see markets and has tutorial USDT (see glossary)

Stop / wipe with `./run-local.sh stop` and `./run-local.sh wipe` from that chapter directory. Do not leave duplicate processes on the same ports.
