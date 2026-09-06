#!/usr/bin/env bash
# No-bridge local stack for event-contract chapter1.
# Starts: lightpool + clob-indexer + backend + frontend + liquidity-maker
# Does NOT start: Reth / lightpool-bridge
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Hardhat/Anvil account #0 — maker / validator / bot
MAKER_KEY="${MAKER_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
MAKER_ADDR="${MAKER_ADDR:-0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266}"

# Hardhat/Anvil account #1 — demo MetaMask user (fixed tutorial key)
USER_KEY="${USER_KEY:-0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d}"
USER_ADDR="${USER_ADDR:-0x70997970C51812dc3A010C7d01b50e0d17dc79C8}"

USER_USDT="${USER_USDT:-1000}"
MAX_MARKETS="${MAX_MARKETS:-4}"
MINT_AMOUNT="${MINT_AMOUNT:-1000000000000000}"
POLYMARKET_SLUG="${POLYMARKET_SLUG:-world-cup-winner}"

LP_RPC="${LP_RPC:-http://127.0.0.1:26300}"
CLOB_HTTP="${LIGHTPOOL_CLOB_INDEX_HTTP:-http://127.0.0.1:3002}"
CLOB_WS="${LIGHTPOOL_CLOB_INDEX_WS:-ws://127.0.0.1:3002}"

resolve_labs() {
  if [[ -n "${LABS:-}" ]]; then
    printf '%s\n' "$LABS"
    return
  fi
  local candidate
  candidate="$(cd "$SCRIPT_DIR/../../.." && pwd)"
  if [[ -d "$candidate/lightpool-node" ]]; then
    printf '%s\n' "$candidate"
    return
  fi
  printf '%s\n' "$(pwd)/lightpool-labs"
}

LABS="$(resolve_labs)"
DATA="${DATA:-$LABS/data/event-contract}"
LOG_DIR="$DATA/logs"
PID_DIR="$DATA/pids"
MARKER="$DATA/.bootstrapped"
CASH_ENV="$DATA/cash.env"
WALLET_PATH="$DATA/wallet.json"
STORE_PATH="$DATA/store"
VALIDATOR_PATH="$DATA/validator.json"
INDEXER_DATA="$DATA/indexer"

NODE_DIR="$LABS/lightpool-node"
INDEXER_DIR="$LABS/lightpool-clob-indexer"
APP_DIR="$LABS/event-contract-app"
BOT_DIR="$LABS/lightpool-bot"

LIGHTPOOL_BIN="${LIGHTPOOL_BIN:-$NODE_DIR/bin/lightpool}"
INDEXER_BIN="${INDEXER_BIN:-$NODE_DIR/bin/lightpool-clob-indexer}"
BACKEND_BIN="${BACKEND_BIN:-$APP_DIR/backend/target/release/event-contract-backend}"
BOT_BIN="${BOT_BIN:-$BOT_DIR/target/release/liquidity-maker}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [start|stop|wipe|status]

  start   Create data dir, bootstrap USDT once, start services (default)
  stop    Stop services started by this script
  wipe    Stop services and delete data dir
  status  Show PIDs

Env:
  LABS            labs workspace (default: auto-detect)
  DATA            runtime data dir (default: \$LABS/data/event-contract)
  HTTPS_PROXY     optional proxy for Polymarket (liquidity-maker)
  MAX_MARKETS     default 4
  USER_USDT       demo user USDT amount (default 1000)
EOF
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 1
  }
}

ensure_bins() {
  if [[ ! -x "$LIGHTPOOL_BIN" ]]; then
    echo "lightpool binary not found: $LIGHTPOOL_BIN" >&2
    echo "Run chapter1 step 3 first (build lightpool-node)." >&2
    exit 1
  fi
  if [[ ! -x "$INDEXER_BIN" ]]; then
    if [[ -x "$INDEXER_DIR/target/release/lightpool-clob-indexer" ]]; then
      INDEXER_BIN="$INDEXER_DIR/target/release/lightpool-clob-indexer"
    else
      echo "indexer binary not found. Build lightpool-clob-indexer (step 3)." >&2
      exit 1
    fi
  fi
  if [[ ! -x "$BACKEND_BIN" ]]; then
    echo "building event-contract-backend..."
    (cd "$APP_DIR/backend" && cargo build --release)
  fi
  if [[ ! -x "$BOT_BIN" ]]; then
    echo "building liquidity-maker..."
    (cd "$BOT_DIR" && cargo build --release -p lightpool-strategies --bin liquidity-maker)
  fi
}

mkdirs() {
  mkdir -p "$DATA" "$LOG_DIR" "$PID_DIR" "$INDEXER_DATA" "$STORE_PATH"
}

is_running() {
  local name="$1"
  local pid_file="$PID_DIR/$name.pid"
  [[ -f "$pid_file" ]] || return 1
  kill -0 "$(cat "$pid_file")" 2>/dev/null
}

stop_one() {
  local name="$1"
  local pid_file="$PID_DIR/$name.pid"
  [[ -f "$pid_file" ]] || return 0
  local pid
  pid="$(cat "$pid_file")"
  if kill -0 "$pid" 2>/dev/null; then
    echo "stop  $name (pid $pid)"
    kill "$pid" 2>/dev/null || true
    local _
    for _ in $(seq 1 20); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.2
    done
    kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$pid_file"
}

wait_node() {
  echo "wait  lightpool RPC $LP_RPC"
  local i
  for i in $(seq 1 60); do
    if curl -fsS -X POST "$LP_RPC" \
      -H 'content-type: application/json' \
      -d '{"jsonrpc":"2.0","id":1,"method":"ping","params":{}}' >/dev/null 2>&1; then
      echo "ok    lightpool RPC"
      return 0
    fi
    sleep 1
  done
  echo "lightpool RPC not ready; see $LOG_DIR/lightpool.log" >&2
  exit 1
}

wait_http() {
  local url="$1"
  local label="$2"
  local i
  echo "wait  $label $url"
  for i in $(seq 1 90); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "ok    $label"
      return 0
    fi
    sleep 1
  done
  echo "$label not ready: $url" >&2
  exit 1
}

lp() {
  "$LIGHTPOOL_BIN" --rpc-url "$LP_RPC" --wallet-path "$WALLET_PATH" "$@"
}

import_maker_wallet() {
  "$LIGHTPOOL_BIN" --wallet-path "$WALLET_PATH" import-wallet --private-key "$MAKER_KEY" --force >/dev/null
}

bootstrap_chain() {
  if [[ -f "$MARKER" ]]; then
    echo "skip  bootstrap (found $MARKER)"
    # shellcheck disable=SC1090
    source "$CASH_ENV"
    return 0
  fi

  echo "boot  create USDT + fund demo user ($USER_USDT USDT -> $USER_ADDR)"
  local out token
  out="$(lp create-token --name USDT --symbol USDT --total-supply 10000000000000 --mintable 2>&1 | tee "$LOG_DIR/create-token.log")"
  token="$(printf '%s\n' "$out" | grep -Eo '0x[0-9a-fA-F]{16,}' | head -1 || true)"
  if [[ -z "$token" ]]; then
    echo "failed to parse token address from create-token output" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi
  echo "ok    CASH_TOKEN_ADDRESS=$token"

  lp transfer --token-address "$token" --to "$USER_ADDR" --amount "$USER_USDT"

  cat >"$CASH_ENV" <<EOF
CASH_TOKEN_ADDRESS=$token
CASH_TOKEN_SYMBOL=USDT
MAKER_ADDR=$MAKER_ADDR
USER_ADDR=$USER_ADDR
EOF
  touch "$MARKER"
  # shellcheck disable=SC1090
  source "$CASH_ENV"
}

write_backend_env() {
  # shellcheck disable=SC1090
  source "$CASH_ENV"
  cat >"$APP_DIR/backend/.env" <<EOF
HOST=0.0.0.0
PORT=3001
CLOB_INDEX_URL=$CLOB_HTTP
DATABASE_URL=memory
CASH_TOKEN_ADDRESS=$CASH_TOKEN_ADDRESS
CASH_TOKEN_SYMBOL=${CASH_TOKEN_SYMBOL:-USDT}
ETH_USDT=
BRIDGE=
EVM_RPC_URL=
EVM_CHAIN_ID=1337
JWT_SECRET=dev-jwt-secret-change-me
AGENT_ENCRYPTION_KEY=dev-agent-encryption-key
EOF
}

write_frontend_env() {
  if [[ ! -f "$APP_DIR/frontend/.env.local" ]]; then
    cat >"$APP_DIR/frontend/.env.local" <<EOF
NEXT_PUBLIC_API_URL=http://127.0.0.1:3001/api
NEXT_PUBLIC_EVM_RPC_URL=
NEXT_PUBLIC_EVM_CHAIN_ID=1337
EOF
  fi
}

print_summary() {
  cat <<EOF

=== event-contract local (no bridge) ===
LABS   $LABS
DATA   $DATA
UI     http://127.0.0.1:3000
API    http://127.0.0.1:3001/api
CLOB   $CLOB_HTTP

Import this fixed private key for the demo user:
  private key  $USER_KEY
  address      $USER_ADDR
  USDT         $USER_USDT (on LightPool after bootstrap)

Maker / validator (node + bot):
  private key  $MAKER_KEY
  address      $MAKER_ADDR

Logs: $LOG_DIR
Stop: $0 stop
Wipe: $0 wipe

Expect: open UI → ~4 events; demo user has ~${USER_USDT} USDT and can place orders
If markets are empty, set HTTPS_PROXY for Polymarket and restart bot.
EOF
}

start_all() {
  need_cmd curl
  need_cmd cargo
  need_cmd npm
  mkdirs
  ensure_bins
  import_maker_wallet

  export PATH="$(dirname "$LIGHTPOOL_BIN"):${PATH:-}"

  if ! is_running lightpool; then
    echo "start lightpool"
    nohup "$LIGHTPOOL_BIN" node --role validator \
      --wallet "$WALLET_PATH" \
      --store "$STORE_PATH" \
      --validator "$VALIDATOR_PATH" \
      >"$LOG_DIR/lightpool.log" 2>&1 &
    echo $! >"$PID_DIR/lightpool.pid"
  else
    echo "skip  lightpool (already running)"
  fi
  wait_node
  bootstrap_chain
  write_backend_env
  write_frontend_env

  if ! is_running indexer; then
    echo "start indexer"
    (
      export LIGHTPOOL_RPC_URL="$LP_RPC"
      export LIGHTPOOL_WS_URL=ws://127.0.0.1:26400
      export ENABLE_INDEXER=true
      export ENABLE_SQLITE=true
      export SQLITE_PATH="$INDEXER_DATA/clob-index.sqlite3"
      nohup "$INDEXER_BIN" >"$LOG_DIR/indexer.log" 2>&1 &
      echo $! >"$PID_DIR/indexer.pid"
    )
  else
    echo "skip  indexer (already running)"
  fi
  wait_http "$CLOB_HTTP/health/health" "clob-indexer"

  if ! is_running backend; then
    echo "start backend"
    (
      cd "$APP_DIR/backend"
      set -a
      # shellcheck disable=SC1091
      source .env
      set +a
      nohup "$BACKEND_BIN" >"$LOG_DIR/backend.log" 2>&1 &
      echo $! >"$PID_DIR/backend.pid"
    )
  else
    echo "skip  backend (already running)"
  fi
  wait_http "http://127.0.0.1:3001/api/health/health" "backend"

  if [[ ! -d "$APP_DIR/frontend/node_modules" ]]; then
    echo "npm install (frontend)"
    (cd "$APP_DIR/frontend" && npm install)
  fi
  if ! is_running frontend; then
    echo "start frontend"
    (
      cd "$APP_DIR/frontend"
      nohup npm run dev >"$LOG_DIR/frontend.log" 2>&1 &
      echo $! >"$PID_DIR/frontend.pid"
    )
  else
    echo "skip  frontend (already running)"
  fi

  # shellcheck disable=SC1090
  source "$CASH_ENV"
  if ! is_running bot; then
    echo "start liquidity-maker (bootstrap $MAX_MARKETS markets)"
    (
      cd "$BOT_DIR"
      export LIGHTPOOL_CLOB_INDEX_HTTP="$CLOB_HTTP"
      export LIGHTPOOL_CLOB_INDEX_WS="$CLOB_WS"
      export LIGHTPOOL_COLLATERAL_TOKEN="$CASH_TOKEN_ADDRESS"
      export LIGHTPOOL_PRIVATE_KEY="$MAKER_KEY"
      nohup "$BOT_BIN" \
        --polymarket-slug "$POLYMARKET_SLUG" \
        --bootstrap-markets \
        --max-markets "$MAX_MARKETS" \
        --mint-amount "$MINT_AMOUNT" \
        >"$LOG_DIR/bot.log" 2>&1 &
      echo $! >"$PID_DIR/bot.pid"
    )
  else
    echo "skip  bot (already running)"
  fi

  print_summary
}

stop_all() {
  stop_one bot
  stop_one frontend
  stop_one backend
  stop_one indexer
  stop_one lightpool
  echo "stopped"
}

wipe_all() {
  stop_all
  rm -rf "$DATA"
  echo "wiped $DATA"
}

status_all() {
  echo "LABS=$LABS"
  echo "DATA=$DATA"
  local name
  for name in lightpool indexer backend frontend bot; do
    if is_running "$name"; then
      echo "UP   $name pid=$(cat "$PID_DIR/$name.pid")"
    else
      echo "DOWN $name"
    fi
  done
}

cmd="${1:-start}"
case "$cmd" in
  start) start_all ;;
  stop) stop_all ;;
  wipe) wipe_all ;;
  status) status_all ;;
  -h|--help|help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
