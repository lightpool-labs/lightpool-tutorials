#!/usr/bin/env bash
# Chapter 6: start LightPool node, indexer, app, markets, and maker funds.
# stop only stops processes. clean only deletes data (run stop first).
# 1. Start lightpool node + clob-indexer (./scripts/run-venue.sh)
# 2. Start backend + frontend
# 3. Create USDT and AAPL / TSLA / INTC markets
# 4. Fund the maker wallet (./scripts/fund-maker.sh)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
export LABS DATA
LOG_DIR="$DATA/logs"
PID_DIR="$DATA/pids"
APP_DIR="${APP_DIR:-$LABS/tokenized-stocks-app}"
APP_API="${APP_API:-http://127.0.0.1:3001/api}"
VENUE="$SCRIPT_DIR/run-venue.sh"
FUND="$SCRIPT_DIR/fund-maker.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [start|stop|clean]

Chapter 6 local stocks stack.

  start   Node, indexer, backend, frontend, USDT + AAPL/TSLA/INTC, fund maker (default)
  stop    Stop backend, frontend, node, and indexer. Keep data.
  clean   Delete \$DATA only. Does not stop. Run stop first if anything is still up.

Env:
  LABS     labs workspace (default: auto-detect)
  DATA     runtime dir (default: \$LABS/data/tokenized-stocks)
  APP_DIR  tokenized-stocks-app (default: \$LABS/tokenized-stocks-app)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 1
  }
}

mkdirs() {
  mkdir -p "$LOG_DIR" "$PID_DIR"
}

is_running() {
  local name="$1"
  local pid_file="$PID_DIR/$name.pid"
  [[ -f "$pid_file" ]] || return 1
  kill -0 "$(cat "$pid_file")" 2>/dev/null
}

stop_pid() {
  local name="$1"
  local pid_file="$PID_DIR/$name.pid"
  [[ -f "$pid_file" ]] || return 0
  local pid
  pid="$(cat "$pid_file")"
  if kill -0 "$pid" 2>/dev/null; then
    echo "stop  $name (pid $pid)"
    kill -- -"$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
    local _
    for _ in $(seq 1 20); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.2
    done
    kill -9 -- -"$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$pid_file"
}

stop_port() {
  local port="$1"
  local name="$2"
  local pids pid
  pids="$(ss -lptnH "sport = :$port" 2>/dev/null | grep -o 'pid=[0-9]*' | cut -d= -f2 | sort -u || true)"
  [[ -n "$pids" ]] || return 0
  for pid in $pids; do
    echo "stop  $name (pid $pid port $port)"
    kill "$pid" 2>/dev/null || true
  done
  sleep 0.5
  for pid in $pids; do
    kill -0 "$pid" 2>/dev/null || continue
    kill -9 "$pid" 2>/dev/null || true
  done
}

stop_app() {
  echo "=== stop backend and frontend ==="
  stop_pid frontend
  stop_pid backend
  stop_port 3000 frontend
  stop_port 3001 backend
}

wait_http() {
  local url="$1"
  local name="$2"
  local i body
  echo "wait  $name $url"
  for i in $(seq 1 60); do
    body="$(curl -fsS "$url" 2>/dev/null || true)"
    if [[ -n "$body" ]]; then
      echo "ok    $name"
      return 0
    fi
    sleep 1
  done
  echo "$name not ready: $url" >&2
  exit 1
}

backend_bin() {
  if [[ -n "${BACKEND_BIN:-}" && -x "$BACKEND_BIN" ]]; then
    printf '%s\n' "$BACKEND_BIN"
    return
  fi
  if [[ -x "$APP_DIR/backend/target/release/tokenized-stocks-backend" ]]; then
    printf '%s\n' "$APP_DIR/backend/target/release/tokenized-stocks-backend"
    return
  fi
  if [[ -x "$APP_DIR/backend/target/debug/tokenized-stocks-backend" ]]; then
    printf '%s\n' "$APP_DIR/backend/target/debug/tokenized-stocks-backend"
    return
  fi
  printf '%s\n' ""
}

start_backend() {
  if is_running backend; then
    echo "skip  backend (already running)"
    return
  fi
  if [[ ! -f "$APP_DIR/backend/.env" && -f "$APP_DIR/backend/.env.example" ]]; then
    cp "$APP_DIR/backend/.env.example" "$APP_DIR/backend/.env"
  fi
  local bin
  bin="$(backend_bin)"
  echo "start backend"
  if [[ -n "$bin" ]]; then
    (
      cd "$APP_DIR/backend"
      setsid "$bin" >"$LOG_DIR/backend.log" 2>&1 < /dev/null &
      echo $! >"$PID_DIR/backend.pid"
    )
  else
    (
      cd "$APP_DIR/backend"
      setsid cargo run >"$LOG_DIR/backend.log" 2>&1 < /dev/null &
      echo $! >"$PID_DIR/backend.pid"
    )
  fi
}

start_frontend() {
  if is_running frontend; then
    echo "skip  frontend (already running)"
    return
  fi
  if [[ ! -f "$APP_DIR/frontend/.env.local" && -f "$APP_DIR/frontend/.env.example" ]]; then
    cp "$APP_DIR/frontend/.env.example" "$APP_DIR/frontend/.env.local"
  fi
  if [[ ! -d "$APP_DIR/frontend/node_modules" ]]; then
    echo "npm install (frontend)"
    (cd "$APP_DIR/frontend" && npm install)
  fi
  echo "start frontend"
  (
    cd "$APP_DIR/frontend"
    setsid npm run dev >"$LOG_DIR/frontend.log" 2>&1 < /dev/null &
    echo $! >"$PID_DIR/frontend.pid"
  )
}

post_json() {
  local path="$1"
  local body="${2:-}"
  local out="$LOG_DIR/last-api.json"
  local code
  if [[ -n "$body" ]]; then
    code="$(curl -sS -o "$out" -w '%{http_code}' -X POST "$APP_API$path" \
      -H 'content-type: application/json' \
      -d "$body")"
  else
    code="$(curl -sS -o "$out" -w '%{http_code}' -X POST "$APP_API$path")"
  fi
  printf '%s\n' "$code"
}

create_markets() {
  echo "=== create USDT and AAPL / TSLA / INTC ==="
  local code
  code="$(post_json "/admin/ensure-cash")"
  if [[ "$code" != "200" && "$code" != "201" ]]; then
    echo "ensure USDT failed ($code): $(cat "$LOG_DIR/last-api.json")" >&2
    exit 1
  fi
  echo "ok    USDT $(cat "$LOG_DIR/last-api.json")"

  local symbol name
  while IFS='|' read -r symbol name; do
    code="$(post_json "/admin/markets" "{\"symbol\":\"$symbol\",\"name\":\"$name\"}")"
    if [[ "$code" == "200" || "$code" == "201" ]]; then
      echo "ok    $symbol $(cat "$LOG_DIR/last-api.json")"
    elif grep -q 'already registered' "$LOG_DIR/last-api.json"; then
      echo "skip  $symbol (already registered)"
    else
      echo "create $symbol failed ($code): $(cat "$LOG_DIR/last-api.json")" >&2
      exit 1
    fi
  done <<'EOF'
AAPL|Apple
TSLA|Tesla
INTC|Intel
EOF
}

stop_all() {
  need_cmd ss
  stop_app
  echo "=== stop lightpool node and indexer ==="
  "$VENUE" stop
}

clean_all() {
  local name
  for name in frontend backend lightpool indexer; do
    if is_running "$name"; then
      echo "services still running; run: $0 stop" >&2
      echo "then: $0 clean" >&2
      exit 1
    fi
  done
  rm -rf "$DATA"
  echo "cleaned $DATA (node store, indexer, registry, course runtime)"
}

start_all() {
  need_cmd curl
  need_cmd ss
  mkdirs
  echo "=== start lightpool node and indexer ==="
  "$VENUE" start
  echo "=== start backend and frontend ==="
  start_backend
  start_frontend
  wait_http "$APP_API/health" "backend"
  create_markets
  echo "=== fund maker ==="
  "$FUND"
}

main() {
  case "${1:-start}" in
    start) start_all ;;
    stop) stop_all ;;
    clean) clean_all ;;
    -h|--help|help) usage ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
