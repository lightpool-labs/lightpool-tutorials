# Tokenized stocks — Chapter 7: Deposit / withdraw

One prompt. The startup script is already in this repo. Do not ask an AI to write the script.

From `lightpool-tutorials/`:

```bash
./scripts/start-stocks-07.sh
./scripts/start-stocks-07.sh stop
./scripts/start-stocks-07.sh clean
```

`start` brings up Reth, the LightPool node, clob-index, the bridge, USDT and AAPL/TSLA/INTC, maker deposit, and the app. `stop` only stops processes. `clean` only deletes `$LABS/data/tokenized-stocks` after `stop`.

## Prompt (copy to your AI)

```text
Please read lightpool-tutorials/prompts/tokenized-stocks-app-07-deposit-withdraw.txt. On tokenized-stocks-app, Connect in the top bar must ask MetaMask to sign and create an agent for that account. Deposit and Withdraw stay on the order ticket and must ask MetaMask to sign. Do not add a new page and do not move those buttons.
```

## Verify

Prerequisite: `./scripts/start-stocks-07.sh` has finished. Use the log it prints.

1. In MetaMask, add the network from **MetaMask network** (RPC URL and Chain ID).
2. Import the **Demo user** private key. Add the **USDT** ERC20 from the log (6 decimals). Do not use the LightPool `0x02…` token address.
3. Open http://127.0.0.1:3000. Click **Connect**. MetaMask must sign, and the top bar shows the demo address.
4. In the order ticket, **Deposit** a small USDT amount. MetaMask signs approve, then deposit.
5. In the bottom user state block, open the **Balances** tab. The connected user must show USDT with Available greater than 0. Open orders, History, and Fills stay empty.
