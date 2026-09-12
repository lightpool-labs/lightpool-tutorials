# Architecture

LightPool is a self-deployed L1. Operators run a node + clob-index. Apps integrate with **that** clob-index URL.

```text
Your app  ──HTTP / WS──►  clob-index (:3002)  ──RPC/WS──►  lightpool node
                              ▲
                     lightpool-sdk signed tx
                     POST /api/tx/submit
```

Do not send market-data or place/cancel requests to node RPC `:26300`. The indexer is the app-facing API.

API field shapes: [`../skills/spot-lightpool/SKILL.md`](../skills/spot-lightpool/SKILL.md).

## Event contract (chapter 1: no bridge)

```text
Browser  :3000 (Next.js)
    │
    ▼
event-contract-app backend  :3001
    │
    ▼
clob-index  :3002  ◄──  liquidity-maker (bootstrap YES/NO books)
    │
    ▼
lightpool validator  :26300 / :26400
```

What starts (`event-contract/chapter1-run-local/run-local.sh`):

1. `lightpool node --role validator`
2. clob-index (HTTP/WS `:3002`, node RPC/WS behind it)
3. event-contract backend + frontend
4. `liquidity-maker` with `--bootstrap-markets` (up to 4 events)

What does **not** start in chapter 1: Reth, `lightpool-bridge`, MetaMask L1 deposit.

Local cash path:

```text
maker wallet ──create-token USDT──► CASH_TOKEN_ADDRESS (0x02…)
maker wallet ──transfer 1000 USDT──► demo user Address
liquidity-maker mints/uses that cash as collateral for event markets
```

Each event has collateral plus YES/NO tokens and **two** spot markets (YES book and NO book). The app still reads books and submits orders through clob-index, using those spot `ContractAddress` values.

## Tokenized stocks (spot exchange)

No event YES/NO layer. One CLOB per pair:

```text
Your exchange UI / API
    │
    ▼
clob-index  :3002
    │
    ▼
lightpool node
```

Typical setup:

1. `create-token` quote (USDT)
2. `create-token` base (e.g. AAPL)
3. `create-spot-market` AAPL/USDT → spot `ContractAddress` (`0x03…`)
4. Fund maker/taker `Address`es
5. App: `GET /api/spot/:spot_market/book`, WS channels, `POST /api/tx/submit`

Event-contract demo UI/backend is optional here. Node + clob-index are enough for a minimal exchange.

## Bridge (later; not chapter 1)

```text
User MetaMask ──► Reth MockUSDT (:8545) ──► EVM Bridge
                                              │
                                         lightpool-bridge
                                              │
                                              ▼
                                    LightPool LP USDT (cash)
```

Use this only when a chapter says so. Wipe or use a new data dir; do not reuse a chapter-1 mint cash token as if it were bridged LP USDT.

## Signing and submit

```text
Signer (user key)
    → ActionBuilder (place_order / cancel_order / transfer / …)
    → TransactionBuilder.build_and_sign_only
    → POST http://127.0.0.1:3002/api/tx/submit  { "tx": SignedTransaction }
    → digest + receipt
```

Details: [`../skills/spot-lightpool/tx-submit.md`](../skills/spot-lightpool/tx-submit.md).

## Process boundaries

| Component | Owns |
|-----------|------|
| lightpool node | Chain, matching, settlement |
| clob-index | Indexed books, HTTP/WS, tx submit gateway |
| event-contract-app | Product API/UI (auth, market list UX) |
| liquidity-maker | Demo inventory / bootstrap |
| lightpool-bridge | EVM cash in/out |

When wiring a new app, treat clob-index + lightpool-sdk as the integration surface. Copy product UX from `event-contract-app` only when building the event-contract track.
