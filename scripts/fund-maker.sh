#!/usr/bin/env bash
# Fund the maker wallet with USDT (for bids) and equity tokens (for asks).
# Requires: venue running, Admin already created USDT + AAPL/TSLA/INTC markets,
#           tokenized-stocks-app backend up (or a local registry.json).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Hardhat / Anvil account #0 — validator / admin / maker
MAKER_KEY="${MAKER_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
MAKER_ADDR="${MAKER_ADDR:-0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266}"

LP_RPC="${LP_RPC:-http://127.0.0.1:26300}"
APP_API="${APP_API:-http://127.0.0.1:3001/api}"

# Whole-token amounts (lightpool CLI scales by 1e6).
# Maker mirrors Hyperliquid L2 depth; keep inventory large enough for full books.
USDT_AMOUNT="${USDT_AMOUNT:-10000000000}"
STOCK_AMOUNT="${STOCK_AMOUNT:-1000000000}"
SYMBOLS="${SYMBOLS:-AAPL,TSLA,INTC}"

resolve_labs() {
  if [[ -n "${LABS:-}" ]]; then
    printf '%s\n' "$LABS"
    return
  fi
  local candidate
  candidate="$(cd "$SCRIPT_DIR/../.." && pwd)"
  if [[ -d "$candidate/lightpool-node" ]]; then
    printf '%s\n' "$candidate"
    return
  fi
  printf '%s\n' "$(pwd)/lightpool-labs"
}

LABS="$(resolve_labs)"
DATA="${DATA:-$LABS/data/tokenized-stocks}"
WALLET_PATH="${WALLET_PATH:-$DATA/wallet.json}"
REGISTRY_PATH="${REGISTRY_PATH:-$LABS/data/tokenized-stocks/registry.json}"

NODE_DIR="$LABS/lightpool-node"
LIGHTPOOL_BIN="${LIGHTPOOL_BIN:-$NODE_DIR/bin/lightpool}"

usage() {
  cat <<EOF
Usage: $(basename "$0")

Mint USDT + equity tokens to the maker wallet so equity-liquidity-maker can
place bids (needs USDT) and asks (needs AAPL / TSLA / INTC).

Prerequisite:
  - ./scripts/run-venue.sh start
  - tokenized-stocks-app Admin created USDT and markets for: $SYMBOLS

Env:
  LABS            labs workspace (default: auto-detect)
  DATA            venue data dir (default: \$LABS/data/tokenized-stocks)
  APP_API         app API base (default: http://127.0.0.1:3001/api)
  REGISTRY_PATH   fallback registry.json if API is down
  MAKER_ADDR      recipient (default: Anvil #0)
  USDT_AMOUNT     whole USDT to mint (default: 10000000000 = 10B)
  STOCK_AMOUNT    whole shares per symbol (default: 1000000000 = 1B)
  SYMBOLS         comma-separated bases (default: AAPL,TSLA,INTC)
EOF
}

need_bin() {
  if [[ ! -x "$LIGHTPOOL_BIN" ]]; then
    echo "lightpool binary not found: $LIGHTPOOL_BIN" >&2
    exit 1
  fi
}

lp() {
  "$LIGHTPOOL_BIN" --rpc-url "$LP_RPC" --wallet-path "$WALLET_PATH" "$@"
}

ensure_wallet() {
  if [[ ! -f "$WALLET_PATH" ]]; then
    echo "wallet missing: $WALLET_PATH (run ./scripts/run-venue.sh start first)" >&2
    exit 1
  fi
  "$LIGHTPOOL_BIN" --wallet-path "$WALLET_PATH" import-wallet --private-key "$MAKER_KEY" --force >/dev/null
}

load_from_api() {
  local cash_json markets_json
  cash_json="$(curl -fsS "$APP_API/cash" 2>/dev/null)" || return 1
  markets_json="$(curl -fsS "$APP_API/markets" 2>/dev/null)" || return 1

  if command -v jq >/dev/null 2>&1; then
    CASH_TOKEN="$(printf '%s' "$cash_json" | jq -r '.cash_token // empty')"
    MARKETS_JSON="$markets_json"
  else
    CASH_TOKEN="$(python3 -c "import json,sys; print(json.load(sys.stdin).get('cash_token') or '')" <<<"$cash_json")"
    MARKETS_JSON="$markets_json"
  fi

  [[ -n "$CASH_TOKEN" && "$CASH_TOKEN" != "null" ]]
}

load_from_registry() {
  [[ -f "$REGISTRY_PATH" ]] || return 1
  if command -v jq >/dev/null 2>&1; then
    CASH_TOKEN="$(jq -r '.cash_token // empty' "$REGISTRY_PATH")"
    MARKETS_JSON="$(jq -c '{markets: .markets}' "$REGISTRY_PATH")"
  else
    CASH_TOKEN="$(python3 -c "import json; d=json.load(open('$REGISTRY_PATH')); print(d.get('cash_token') or '')")"
    MARKETS_JSON="$(python3 -c "import json; d=json.load(open('$REGISTRY_PATH')); print(json.dumps({'markets': d.get('markets') or []}))")"
  fi
  [[ -n "$CASH_TOKEN" && "$CASH_TOKEN" != "null" ]]
}

base_token_for_symbol() {
  local symbol="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$MARKETS_JSON" | jq -r --arg s "$symbol" '
      (.markets // [])
      | map(select((.symbol | ascii_upcase) == ($s | ascii_upcase)))
      | .[0].base_token // empty
    '
  else
    python3 -c "
import json, sys
symbol = sys.argv[1].upper()
markets = json.load(sys.stdin).get('markets') or []
for m in markets:
    if str(m.get('symbol','')).upper() == symbol:
        print(m.get('base_token') or '')
        break
" "$symbol" <<<"$MARKETS_JSON"
  fi
}

mint_to_maker() {
  local label="$1"
  local token="$2"
  local amount="$3"
  echo "mint  $label  amount=$amount  token=$token  to=$MAKER_ADDR"
  lp mint --token-address "$token" --amount "$amount" --to "$MAKER_ADDR"
}

show_balance() {
  local label="$1"
  local token="$2"
  echo -n "bal   $label  "
  lp balance --token-address "$token" --account "$MAKER_ADDR" 2>/dev/null | tail -n 5 || true
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  need_bin
  ensure_wallet

  echo "wait  lightpool RPC $LP_RPC"
  local i body
  for i in $(seq 1 30); do
    body="$(curl -fsS -X POST "$LP_RPC" \
      -H 'content-type: application/json' \
      -d '{"jsonrpc":"2.0","id":1,"method":"getClientVersion","params":[]}' 2>/dev/null || true)"
    if echo "$body" | grep -Eq '"result"[[:space:]]*:[[:space:]]*"[^"]+"'; then
      break
    fi
    if [[ "$i" -eq 30 ]]; then
      echo "lightpool RPC not ready: $LP_RPC" >&2
      exit 1
    fi
    sleep 1
  done

  CASH_TOKEN=""
  MARKETS_JSON=""
  if load_from_api; then
    echo "ok    loaded tokens from $APP_API"
  elif load_from_registry; then
    echo "ok    loaded tokens from $REGISTRY_PATH"
  else
    echo "failed to load cash/markets from $APP_API or $REGISTRY_PATH" >&2
    echo "Create USDT + markets in Admin first, then re-run." >&2
    exit 1
  fi

  echo "fund  maker=$MAKER_ADDR"
  mint_to_maker "USDT" "$CASH_TOKEN" "$USDT_AMOUNT"

  IFS=',' read -r -a SYMBOL_LIST <<<"$SYMBOLS"
  local sym token
  for sym in "${SYMBOL_LIST[@]}"; do
    sym="$(echo "$sym" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"
    [[ -n "$sym" ]] || continue
    token="$(base_token_for_symbol "$sym")"
    if [[ -z "$token" || "$token" == "null" ]]; then
      echo "skip  $sym (base_token not in registry — create market in Admin)" >&2
      continue
    fi
    mint_to_maker "$sym" "$token" "$STOCK_AMOUNT"
  done

  echo
  echo "=== maker balances ==="
  show_balance "USDT" "$CASH_TOKEN"
  for sym in "${SYMBOL_LIST[@]}"; do
    sym="$(echo "$sym" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"
    [[ -n "$sym" ]] || continue
    token="$(base_token_for_symbol "$sym")"
    [[ -n "$token" && "$token" != "null" ]] || continue
    show_balance "$sym" "$token"
  done

  cat <<EOF

Done. Maker can buy with USDT and sell AAPL/TSLA/INTC.
Next: run equity-liquidity-maker (chapter 6a).
EOF
}

main "$@"
