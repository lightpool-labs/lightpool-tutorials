# Tokenized stocks — Chapter 4: Admin (+ markets list)

**Goal:** Wire Admin (create USDT + stock token, create spot market, fund accounts) and the markets list so the trade UI can select a real spot `ContractAddress`.

**Prerequisite:** Chapter 2–3 app shell; local venue (node + clob-index) running.

**Agents:** detailed instructions in [`../../prompts/tokenized-stocks-app-04-admin.txt`](../../prompts/tokenized-stocks-app-04-admin.txt).

**Layout reference:** [`../tokenized-stocks-video-by-chapter.md`](../tokenized-stocks-video-by-chapter.md) (step 4).

## Run local venue (node + indexer)

From `lightpool-tutorials/`:

```bash
./scripts/run-venue.sh start
```

| Command | Effect |
|---------|--------|
| `./scripts/run-venue.sh start` | Start validator + clob-indexer |
| `./scripts/run-venue.sh status` | Show PIDs |
| `./scripts/run-venue.sh stop` | Stop services |
| `./scripts/run-venue.sh clean` | Delete `$LABS/data/tokenized-stocks` only (run `stop` first) |

| Service | URL |
|---------|-----|
| LightPool RPC | `http://127.0.0.1:26300` |
| clob-index HTTP | `http://127.0.0.1:3002` |
| clob-index WS | `ws://127.0.0.1:3002/api/ws` |

App traffic goes to **clob-index** only (`:3002`), not node RPC.

Verify:

```bash
curl -s http://127.0.0.1:3002/api/health/health
```

## Test accounts (local only)

Hardhat / Anvil defaults. Never use on a real network.

| Role | Anvil # | Address | Private key |
|------|---------|---------|-------------|
| Validator / admin / maker | 0 | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` |
| Trader (demo user) | 1 | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d` |
| Trader 2 | 2 | `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC` | `0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a` |
| Trader 3 | 3 | `0x90F79bf6EB2c4f870365E785982E1f101E93b906` | `0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6` |
| Trader 4 | 4 | `0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65` | `0x47e179ec197488593b187bdd29183f6620c5ed4814f96868e1b8251b274a2d` |

`run-venue.sh` imports Anvil #0 into the node wallet under `$LABS/data/tokenized-stocks/wallet.json`.

## Prompt (copy to your AI)

```text
Please read lightpool-tutorials/prompts/tokenized-stocks-app-04-admin.txt. Help me implement Admin (+ markets list) on tokenized-stocks-app. Admin must sign with the same key as the LightPool validator (Anvil #0). First token must be USDT as cash. Creating an AAPL market must create the AAPL token and the AAPL/USDT spot market. Wire the trade-page markets list to real pairs.
```
