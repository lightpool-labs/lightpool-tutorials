#!/usr/bin/env bash
# Start local LightPool venue: validator node + clob-indexer only.
# Does NOT start app backend/frontend, bot, Reth, or bridge.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Hardhat/Anvil account #0 — node validator wallet
MAKER_KEY="${MAKER_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
MAKER_ADDR="${MAKER_ADDR:-0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266}"

LP_RPC="${LP_RPC:-http://127.0.0.1:26300}"
CLOB_HTTP="${LIGHTPOOL_CLOB_INDEX_HTTP:-http://127.0.0.1:3002}"

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
LOG_DIR="$DATA/logs"
PID_DIR="$DATA/pids"
WALLET_PATH="$DATA/wallet.json"
STORE_PATH="$DATA/store"
VALIDATOR_PATH="$DATA/validator.json"
INDEXER_DATA="$DATA/indexer"

NODE_DIR="$LABS/lightpool-node"
INDEXER_DIR="$LABS/lightpool-clob-indexer"

LIGHTPOOL_BIN="${LIGHTPOOL_BIN:-$NODE_DIR/bin/lightpool}"
INDEXER_BIN="${INDEXER_BIN:-$NODE_DIR/bin/lightpool-clob-indexer}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [start|stop|clean|status]

  start   Start lightpool validator + clob-indexer (default)
  stop    Stop services started by this script
  clean   Delete data dir only (does not stop; run stop first if needed)
  status  Show PIDs

Env:
  LABS            labs workspace (default: auto-detect)
  DATA            runtime data dir (default: \$LABS/data/tokenized-stocks)
  LIGHTPOOL_BIN   path to lightpool CLI
  INDEXER_BIN     path to lightpool-clob-indexer
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
    echo "Build lightpool-node (cargo build --release) and ensure bin/lightpool exists." >&2
    exit 1
  fi
  if [[ ! -x "$INDEXER_BIN" ]]; then
    if [[ -x "$INDEXER_DIR/target/release/lightpool-clob-indexer" ]]; then
      INDEXER_BIN="$INDEXER_DIR/target/release/lightpool-clob-indexer"
    else
      echo "indexer binary not found. Build lightpool-clob-indexer." >&2
      exit 1
    fi
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

# True if JSON-RPC body has a string "result" and no "error".
jsonrpc_has_result() {
  local body="$1"
  echo "$body" | grep -Eq '"result"[[:space:]]*:[[:space:]]*"[^"]+"' || return 1
  echo "$body" | grep -q '"error"' && return 1
  return 0
}

wait_node() {
  echo "wait  lightpool getClientVersion $LP_RPC"
  local i body
  for i in $(seq 1 60); do
    body="$(curl -fsS -X POST "$LP_RPC" \
      -H 'content-type: application/json' \
      -d '{"jsonrpc":"2.0","id":1,"method":"getClientVersion","params":[]}' 2>/dev/null || true)"
    if jsonrpc_has_result "$body"; then
      echo "ok    lightpool RPC ($(echo "$body" | sed -n 's/.*"result"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'))"
      return 0
    fi
    sleep 1
  done
  echo "lightpool RPC not ready; see $LOG_DIR/lightpool.log" >&2
  exit 1
}

wait_indexer_version() {
  local url="$CLOB_HTTP/api/health/client_version"
  local i body
  echo "wait  clob-indexer get_client_version $url"
  for i in $(seq 1 90); do
    body="$(curl -fsS "$url" 2>/dev/null || true)"
    if echo "$body" | grep -Eq '"client_version"[[:space:]]*:[[:space:]]*"[^"]+"'; then
      echo "ok    clob-indexer ($(echo "$body" | sed -n 's/.*"client_version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'))"
      return 0
    fi
    sleep 1
  done
  echo "clob-indexer not ready: $url" >&2
  exit 1
}

import_maker_wallet() {
  "$LIGHTPOOL_BIN" --wallet-path "$WALLET_PATH" import-wallet --private-key "$MAKER_KEY" --force >/dev/null
}

print_summary() {
  cat <<EOF

=== LightPool venue (node + clob-index) ===
LABS      $LABS
DATA      $DATA
RPC       $LP_RPC
CLOB      $CLOB_HTTP
CLOB WS   ws://127.0.0.1:3002/api/ws

Validator wallet (Anvil #0):
  address      $MAKER_ADDR
  private key  $MAKER_KEY

Logs: $LOG_DIR
Stop: $0 stop
Clean: $0 clean

Verify:
  curl -s -X POST $LP_RPC -H 'content-type: application/json' \\
    -d '{"jsonrpc":"2.0","id":1,"method":"getClientVersion","params":[]}'
  curl -s $CLOB_HTTP/api/health/client_version
EOF
}

start_all() {
  need_cmd curl
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
  wait_indexer_version

  print_summary
}

stop_all() {
  stop_one indexer
  stop_one lightpool
  echo "stopped"
}

clean_all() {
  if is_running lightpool || is_running indexer; then
    echo "services still running; run: $0 stop" >&2
    echo "then: $0 clean" >&2
    exit 1
  fi
  rm -rf "$DATA"
  echo "cleaned $DATA"
}

status_all() {
  echo "LABS=$LABS"
  echo "DATA=$DATA"
  local name
  for name in lightpool indexer; do
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
  clean) clean_all ;;
  status) status_all ;;
  -h|--help|help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
