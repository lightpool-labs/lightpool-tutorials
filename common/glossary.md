# Glossary

Facts for agents. Do not invent extra types or ports.

## Address vs ContractAddress

| Type | Meaning | Typical hex |
|------|---------|-------------|
| `Address` | User / wallet account | 20-byte `0x…` (40 hex chars after `0x`) |
| `ContractAddress` | On-chain module: token, spot market, event contract | 8-byte module-prefixed `0x…` (16 hex chars after `0x`) |

| Prefix | What |
|--------|------|
| `0x02…` | Token (USDT, AAPL, YES, NO, …) |
| `0x03…` | Spot market (CLOB) |

Do not pass a user `Address` where a `ContractAddress` is required, or the reverse.

Event-contract markets expose both: a market id/slug plus `yes_spot_market` / `no_spot_market` (`ContractAddress`) and `yes_token` / `no_token` / `collateral_token` (`ContractAddress`). Tokenized stocks use one spot market with **base** (e.g. AAPL) and **quote** (e.g. USDT).

## Ports (local defaults)

| Port | Service | App should use? |
|------|---------|-----------------|
| `3000` | Event-contract UI | Browser only |
| `3001` | Event-contract backend | UI → this API |
| `3002` | clob-index HTTP + WS | **Yes** — books, balances, `POST /api/tx/submit`, `ws://127.0.0.1:3002/api/ws` |
| `26300` | LightPool node RPC | Node/CLI/indexer only, not the app |
| `26400` | LightPool node WS | Indexer only, not the app |
| `8545` | Local Reth (bridge chapters) | Not used in event-contract chapter 1 |
| `8787` | lightpool-bridge admin UI | Bridge chapters only |

## Roles (event-contract chapter 1)

| Role | Who | Notes |
|------|-----|--------|
| Validator / maker | Node signer and liquidity-maker | Anvil account #0 |
| Demo user | MetaMask / tutorial trader | Anvil account #1 |
| clob-index | Indexes chain CLOB, serves HTTP/WS | Apps talk here |
| event-contract backend | App API in front of clob-index | Optional product layer |
| liquidity-maker | Bootstraps demo event markets | Needs cash token address |

## Demo keys (local only)

Hardhat/Anvil defaults. Never use on a real network.

| Role | Address | Private key |
|------|---------|-------------|
| Maker / validator | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` |
| Demo user | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d` |

Chapter 1 funds the demo user with **1000 USDT** after `create-token`. Parse `CASH_TOKEN_ADDRESS` from bootstrap output (often `0x0200000000000001` on a fresh store). Do not hard-code the token address if the log printed a different one.

## Tokens and markets

| Name | Track | Meaning |
|------|-------|---------|
| Cash / USDT | Both (local mint in chapter 1) | Quote / collateral `ContractAddress` |
| YES / NO | Event contract | Outcome tokens; each has its own spot book |
| AAPL (example) | Tokenized stocks | Base token |
| Spot market | Both | CLOB `ContractAddress` (`0x03…`) |

Place-order lock:

- **Buy** → `token_address` = quote (USDT or collateral)
- **Sell** → `token_address` = base (AAPL, YES, or NO)

## Sibling repos (clone when a chapter says so)

| Repo | Role |
|------|------|
| `lightpool-node` | Node CLI (`lightpool`) and validator |
| `lightpool-clob-indexer` | clob-index binary |
| `event-contract-app` | Demo UI + backend |
| `lightpool-bot` | `liquidity-maker` |
| `lightpool-bridge` | EVM ↔ LightPool cash (not chapter 1) |
| `lightpool-sdk-rust` | Sign txs (`lightpool_sdk`) |

GitHub org: `lightpool-labs`. SSH: `git@github.com:lightpool-labs/<repo>.git`.

## Cash: mint vs bridge

| Mode | When | Cash source |
|------|------|-------------|
| No bridge (chapter 1) | Local demo | `lightpool create-token` USDT + `transfer` |
| Bridge | Later chapters | Inbound bridge LP USDT from Reth MockUSDT |

Do not mix the two cash models in one data directory.
