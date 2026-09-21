#!/usr/bin/env bash
# Start the local stock deposit stack.
# Calls only ./scripts/run-venue.sh from this directory (LightPool node + indexer).
# 1. Reth
# 2. LightPool node + clob-indexer
# 3. ERC20 tokens on Reth, LP tokens + spot markets on LightPool, bridge routes
# 4. Fund maker and user on Reth, deposit for the maker
# 5. equity-liquidity-maker
# 6. tokenized-stocks-app backend + frontend
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENUE="$SCRIPT_DIR/run-venue.sh"

MAKER_KEY="${MAKER_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
MAKER_ADDR="${MAKER_ADDR:-0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266}"
USER_KEY="${USER_KEY:-0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d}"
USER_ADDR="${USER_ADDR:-0x70997970C51812dc3A010C7d01b50e0d17dc79C8}"

RETH_RPC="${RETH_RPC:-http://127.0.0.1:8545}"
LP_RPC="${LP_RPC:-http://127.0.0.1:26300}"
APP_API="${APP_API:-http://127.0.0.1:3001/api}"

# Whole tokens. ERC20 and LightPool both use 6 decimals.
MAKER_DEPOSIT_WHOLE="${MAKER_DEPOSIT_WHOLE:-1000000}"
MAKER_STOCK_WHOLE="${MAKER_STOCK_WHOLE:-1000000000}"
USER_TOKEN_WHOLE="${USER_TOKEN_WHOLE:-10000}"

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
WALLET_PATH="$DATA/wallet.json"
STATE="$DATA/eth-bridge.json"
BRIDGE_CONFIG="$DATA/bridge-config.json"
REGISTRY="$DATA/registry.json"
RETH_DATADIR="$DATA/reth"
FORGE_DIR="$DATA/forge"
APP_DIR="${APP_DIR:-$LABS/tokenized-stocks-app}"
BOT_DIR="${BOT_DIR:-$LABS/lightpool-bot}"
CONTRACTS="$LABS/lightpool-bridge/contracts"
RETH_BIN="${RETH_BIN:-$LABS/lightpool-node/tools/reth/bin/reth}"
BRIDGE_BIN="${BRIDGE_BIN:-$LABS/lightpool-bridge/target/release/lightpool-bridge}"

if [[ -z "${LIGHTPOOL_BIN:-}" ]]; then
  if [[ -x "$LABS/lightpool/target/release/lightpool" ]]; then
    LIGHTPOOL_BIN="$LABS/lightpool/target/release/lightpool"
  else
    LIGHTPOOL_BIN="$LABS/lightpool-node/bin/lightpool"
  fi
fi

export PATH="${HOME}/.foundry/bin:${PATH:-}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [start|stop|clean]

Start local Ethereum, LightPool, and the stock deposit path.
The only other script this calls is ./scripts/run-venue.sh (node + indexer).

  start   Reth, node, indexer, tokens, bridge map, fund, maker, app (default)
  stop    Stop maker, app, bridge, Reth, node, and indexer. Keep data.
  clean   Delete \$DATA only. Does not stop. Run stop first if anything is still up.

All runtime state is under \$DATA:
  reth/                         Reth chain
  forge/                        Forge cache and broadcast
  bridge-config.json            bridge routes
  bridge-config-events.db       bridge event log
  eth-bridge.json               token and market addresses
  registry.json                 app market list

Maker (Anvil #0): $MAKER_ADDR
User  (Anvil #1): $USER_ADDR
EOF
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 1
  }
}

mkdirs() {
  mkdir -p "$LOG_DIR" "$PID_DIR" "$RETH_DATADIR" "$FORGE_DIR"
}

prepare_forge_home() {
  mkdir -p "$FORGE_DIR"
  cat > "$FORGE_DIR/foundry.toml" <<EOF
[profile.default]
src = "${CONTRACTS}/src"
script = "${CONTRACTS}/script"
out = "${FORGE_DIR}/out"
libs = ["${CONTRACTS}/lib"]
cache_path = "${FORGE_DIR}/cache"
broadcast = "${FORGE_DIR}/broadcast"
solc_version = "0.8.24"
optimizer = true
optimizer_runs = 200
remappings = ["forge-std/=${CONTRACTS}/lib/forge-std/src/"]
EOF
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

stop_reth() {
  echo "=== stop Reth ==="
  stop_pid reth
  stop_port 8545 reth
}

stop_bridge() {
  echo "=== stop bridge ==="
  stop_pid bridge
  stop_port 8787 bridge
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

wait_reth() {
  local i
  echo "wait  Reth $RETH_RPC"
  for i in $(seq 1 60); do
    if cast chain-id --rpc-url "$RETH_RPC" >/dev/null 2>&1; then
      echo "ok    Reth chain-id=$(cast chain-id --rpc-url "$RETH_RPC")"
      return 0
    fi
    sleep 1
  done
  echo "Reth not ready: $RETH_RPC" >&2
  exit 1
}

start_reth() {
  if is_running reth; then
    echo "skip  Reth (already running, datadir $RETH_DATADIR)"
    return
  fi
  if cast chain-id --rpc-url "$RETH_RPC" >/dev/null 2>&1; then
    echo "stop  Reth on :8545 so chain data stays in $RETH_DATADIR"
    stop_port 8545 reth
  fi
  if [[ ! -x "$RETH_BIN" ]]; then
    echo "reth not found: $RETH_BIN" >&2
    exit 1
  fi
  echo "start Reth datadir $RETH_DATADIR"
  setsid "$RETH_BIN" node \
    --dev \
    --dev.block-time 1s \
    --datadir "$RETH_DATADIR" \
    --http \
    --http.addr 127.0.0.1 \
    --http.port 8545 \
    --http.api eth,net,web3,txpool,debug,trace \
    --http.corsdomain '*' \
    --ws \
    --ws.addr 127.0.0.1 \
    --ws.port 8546 \
    --ws.api eth,net,web3,txpool,debug,trace \
    --ws.origins '*' \
    --authrpc.addr 127.0.0.1 \
    --authrpc.port 8551 \
    --engine.persistence-threshold 0 \
    --engine.memory-block-buffer-target 0 \
    >"$LOG_DIR/reth.log" 2>&1 < /dev/null &
  echo $! >"$PID_DIR/reth.pid"
  wait_reth
}

lp() {
  "$LIGHTPOOL_BIN" --rpc-url "$LP_RPC" --wallet-path "$WALLET_PATH" "$@"
}

raw_amount() {
  python3 -c "print(int('$1') * 1_000_000)"
}

parse_labeled() {
  python3 - "$1" "$2" "$3" <<'PY'
import re, sys
text = open(sys.argv[1], errors="replace").read()
text = re.sub(r"\x1b\[[0-9;]*m", "", text)
label, prefix = sys.argv[2], sys.argv[3]
match = re.search(re.escape(label) + r"\s*:?\s*(" + prefix + r"[0-9a-fA-F]{14})", text, re.I)
if not match:
    sys.exit(1)
print(match.group(1))
PY
}

require_lp_ok() {
  local log="$1"
  if grep -Eiq 'initialization failed|Spot market creation failed|Failed to submit transaction|Failed to connect to node|Wallet not found' "$log"; then
    echo "lightpool command failed; see $log" >&2
    exit 1
  fi
}

validator_stake() {
  local body stake
  body="$(curl -fsS -m 10 -X POST "$LP_RPC" -H 'content-type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"getCommitteeInfo","params":[]}' 2>/dev/null || true)"
  stake="$(python3 -c 'import json,sys
raw=sys.stdin.read().strip()
if not raw:
    print("100"); raise SystemExit
try:
    members=(json.loads(raw).get("result") or {}).get("members") or []
except Exception:
    print("100"); raise SystemExit
want="'"$MAKER_ADDR"'".lower()
for member in members:
    if str(member.get("owner") or "").lower()==want and member.get("stake") is not None:
        print(member["stake"]); raise SystemExit
if members and members[0].get("stake") is not None:
    print(members[0]["stake"]); raise SystemExit
print("100")' <<<"$body")"
  printf '%s\n' "$stake"
}

deploy_usdt_and_bridge() {
  local log="$LOG_DIR/forge-usdt.log" stake
  if [[ ! -f "$CONTRACTS/lib/forge-std/src/Test.sol" ]]; then
    echo "forge-std missing under $CONTRACTS/lib. Run: forge install foundry-rs/forge-std" >&2
    echo "(from $CONTRACTS)" >&2
    exit 1
  fi
  stake="$(validator_stake)"
  echo "deploy USDT + EVM Bridge (validator stake $stake)"
  (
    cd "$CONTRACTS"
    VALIDATOR_ETH="$MAKER_ADDR" \
    VALIDATOR_STAKE="$stake" \
    USER_ETH="$USER_ADDR" \
    forge script script/DeployLocal.s.sol:DeployLocal \
      --rpc-url "$RETH_RPC" \
      --broadcast \
      --private-key "$MAKER_KEY" \
      -vv \
      --root "$CONTRACTS" \
      --config-path "$FORGE_DIR/foundry.toml" \
      --cache-path "$FORGE_DIR/cache" \
      -o "$FORGE_DIR/out"
  ) | tee "$log"
  USDT_EVM="$(python3 -c 'import re,sys; t=open(sys.argv[1],errors="replace").read(); m=re.search(r"USDT\s+(0x[0-9a-fA-F]{40})", t); print(m.group(1) if m else "")' "$log")"
  EVM_BRIDGE="$(python3 -c 'import re,sys; t=open(sys.argv[1],errors="replace").read(); m=re.search(r"BRIDGE\s+(0x[0-9a-fA-F]{40})", t); print(m.group(1) if m else "")' "$log")"
  if [[ -z "$USDT_EVM" || -z "$EVM_BRIDGE" ]]; then
    echo "failed to parse USDT / BRIDGE from $log" >&2
    exit 1
  fi
  echo "ok    USDT $USDT_EVM"
  echo "ok    EVM Bridge $EVM_BRIDGE"
}

deploy_stock_token() {
  local name="$1" symbol="$2" log addr
  log="$LOG_DIR/forge-$symbol.log"
  echo "deploy $symbol on Reth" >&2
  (
    cd "$CONTRACTS"
    forge create "${CONTRACTS}/src/MockToken.sol:MockToken" \
      --rpc-url "$RETH_RPC" \
      --private-key "$MAKER_KEY" \
      --broadcast \
      --root "$CONTRACTS" \
      --config-path "$FORGE_DIR/foundry.toml" \
      --cache-path "$FORGE_DIR/cache" \
      -o "$FORGE_DIR/out" \
      --constructor-args "$name" "$symbol"
  ) >"$log" 2>&1
  cat "$log" >&2
  addr="$(grep -oE 'Deployed to: 0x[0-9a-fA-F]{40}' "$log" | awk '{print $3}' | tail -1)"
  if [[ -z "$addr" ]]; then
    echo "failed to parse $symbol address from $log" >&2
    exit 1
  fi
  echo "register $symbol on EVM Bridge" >&2
  cast send "$EVM_BRIDGE" "registerToken(address)" "$addr" \
    --rpc-url "$RETH_RPC" --private-key "$MAKER_KEY" >/dev/null
  echo "ok    $symbol $addr" >&2
  printf '%s\n' "$addr"
}

mint_erc20() {
  local token="$1" to="$2" whole="$3"
  local raw
  raw="$(raw_amount "$whole")"
  cast send "$token" "mint(address,uint256)" "$to" "$raw" \
    --rpc-url "$RETH_RPC" --private-key "$MAKER_KEY" >/dev/null
}

fund_eth() {
  local to="$1" amount="$2"
  cast send "$to" --value "$amount" --rpc-url "$RETH_RPC" --private-key "$MAKER_KEY" >/dev/null \
    || echo "warning: could not send $amount ETH to $to"
}

init_lp_token() {
  local name="$1" symbol="$2" evm="$3" log lp inbound
  log="$LOG_DIR/init-$symbol.log"
  echo "create LightPool token $symbol"
  lp init-bridge \
    --foreign-chain-id "$EVM_CHAIN_ID" \
    --foreign-token "$evm" \
    --name "$name" \
    --symbol "$symbol" >"$log" 2>&1 || true
  cat "$log"
  require_lp_ok "$log"
  lp="$(parse_labeled "$log" "LP token" "0x02" || true)"
  inbound="$(parse_labeled "$log" "Inbound bridge contract" "0x06" || true)"
  if [[ -z "$lp" || -z "$inbound" ]]; then
    echo "failed to parse LP token for $symbol; see $log" >&2
    exit 1
  fi
  echo "ok    $symbol lp=$lp inbound=$inbound"
  LP_TOKEN="$lp"
  INBOUND="$inbound"
}

create_spot() {
  local symbol="$1" base="$2" quote="$3" log spot
  log="$LOG_DIR/spot-$symbol.log"
  echo "create spot market $symbol/USDT" >&2
  lp create-spot-market \
    --name "$symbol/USDT" \
    --base-token "$base" \
    --quote-token "$quote" \
    --allow-market-orders >"$log" 2>&1 || true
  cat "$log" >&2
  require_lp_ok "$log"
  spot="$(parse_labeled "$log" "Spot Market" "0x03" || true)"
  if [[ -z "$spot" ]]; then
    echo "failed to parse spot market for $symbol; see $log" >&2
    exit 1
  fi
  echo "ok    $symbol/USDT $spot" >&2
  printf '%s\n' "$spot"
}

save_state() {
  python3 - "$STATE" "$REGISTRY" "$EVM_CHAIN_ID" "$EVM_BRIDGE" \
    "$MAKER_ADDR" "$USER_ADDR" \
    "$USDT_EVM" "$LP_USDT" "$IN_USDT" \
    "$AAPL_EVM" "$LP_AAPL" "$IN_AAPL" "$SPOT_AAPL" \
    "$TSLA_EVM" "$LP_TSLA" "$IN_TSLA" "$SPOT_TSLA" \
    "$INTC_EVM" "$LP_INTC" "$IN_INTC" "$SPOT_INTC" <<'PY'
import json, sys, uuid
(
    state_path, registry_path, chain_id, evm_bridge, maker, user,
    usdt_evm, lp_usdt, in_usdt,
    aapl_evm, lp_aapl, in_aapl, spot_aapl,
    tsla_evm, lp_tsla, in_tsla, spot_tsla,
    intc_evm, lp_intc, in_intc, spot_intc,
) = sys.argv[1:]
tokens = [
    {"symbol": "USDT", "name": "Tether USD", "evm": usdt_evm, "lp": lp_usdt, "inbound": in_usdt, "spot_market": "", "market_id": ""},
    {"symbol": "AAPL", "name": "Apple", "evm": aapl_evm, "lp": lp_aapl, "inbound": in_aapl, "spot_market": spot_aapl, "market_id": str(uuid.uuid4())},
    {"symbol": "TSLA", "name": "Tesla", "evm": tsla_evm, "lp": lp_tsla, "inbound": in_tsla, "spot_market": spot_tsla, "market_id": str(uuid.uuid4())},
    {"symbol": "INTC", "name": "Intel", "evm": intc_evm, "lp": lp_intc, "inbound": in_intc, "spot_market": spot_intc, "market_id": str(uuid.uuid4())},
]
state = {"evm_chain_id": int(chain_id), "evm_bridge": evm_bridge, "maker": maker, "user": user, "tokens": tokens}
with open(state_path, "w", encoding="utf-8") as handle:
    json.dump(state, handle, indent=2)
    handle.write("\n")
markets = []
for item in tokens:
    if item["symbol"] == "USDT":
        continue
    markets.append({
        "id": item["market_id"],
        "symbol": item["symbol"],
        "name": item["name"],
        "pair": f"{item['symbol']}/USDT",
        "base_token": item["lp"],
        "quote_token": lp_usdt,
        "spot_market": item["spot_market"],
    })
with open(registry_path, "w", encoding="utf-8") as handle:
    json.dump({"cash_token": lp_usdt, "markets": markets}, handle, indent=2)
    handle.write("\n")
print(f"wrote {state_path}")
print(f"wrote {registry_path}")
PY
}

setup_tokens_and_markets() {
  if [[ -f "$STATE" ]]; then
    echo "skip  token and market setup ($STATE already exists)"
    return
  fi
  EVM_CHAIN_ID="$(cast chain-id --rpc-url "$RETH_RPC")"
  prepare_forge_home
  echo "=== create tokens on Reth ==="
  fund_eth "$USER_ADDR" 10ether
  deploy_usdt_and_bridge
  AAPL_EVM="$(deploy_stock_token Apple AAPL)"
  TSLA_EVM="$(deploy_stock_token Tesla TSLA)"
  INTC_EVM="$(deploy_stock_token Intel INTC)"
  echo "fund maker and user on Reth"
  mint_erc20 "$AAPL_EVM" "$MAKER_ADDR" "$MAKER_STOCK_WHOLE"
  mint_erc20 "$TSLA_EVM" "$MAKER_ADDR" "$MAKER_STOCK_WHOLE"
  mint_erc20 "$INTC_EVM" "$MAKER_ADDR" "$MAKER_STOCK_WHOLE"
  mint_erc20 "$AAPL_EVM" "$USER_ADDR" "$USER_TOKEN_WHOLE"
  mint_erc20 "$TSLA_EVM" "$USER_ADDR" "$USER_TOKEN_WHOLE"
  mint_erc20 "$INTC_EVM" "$USER_ADDR" "$USER_TOKEN_WHOLE"

  echo "=== create LightPool tokens and spot markets ==="
  init_lp_token "Tether USD" USDT "$USDT_EVM"
  LP_USDT="$LP_TOKEN"
  IN_USDT="$INBOUND"
  init_lp_token Apple AAPL "$AAPL_EVM"
  LP_AAPL="$LP_TOKEN"
  IN_AAPL="$INBOUND"
  init_lp_token Tesla TSLA "$TSLA_EVM"
  LP_TSLA="$LP_TOKEN"
  IN_TSLA="$INBOUND"
  init_lp_token Intel INTC "$INTC_EVM"
  LP_INTC="$LP_TOKEN"
  IN_INTC="$INBOUND"
  SPOT_AAPL="$(create_spot AAPL "$LP_AAPL" "$LP_USDT")"
  SPOT_TSLA="$(create_spot TSLA "$LP_TSLA" "$LP_USDT")"
  SPOT_INTC="$(create_spot INTC "$LP_INTC" "$LP_USDT")"
  save_state
}

write_bridge_config() {
  python3 - "$STATE" "$BRIDGE_CONFIG" "$WALLET_PATH" "$LP_RPC" "$RETH_RPC" <<'PY'
import json, sys
state_path, config_path, wallet, lp_rpc, reth_rpc = sys.argv[1:]
state = json.load(open(state_path, encoding="utf-8"))
routes = []
for token in state["tokens"]:
    routes.append({
        "id": "reth-" + token["symbol"].lower(),
        "enabled": True,
        "local_inbound": {
            "bridge_contract": token["inbound"],
            "lp_token": token["lp"],
        },
        "foreign": {
            "kind": "evm",
            "rpc_url": reth_rpc,
            "chain_id": state["evm_chain_id"],
            "bridge_address": state["evm_bridge"],
            "token_address": token["evm"],
            "confirmations": 1,
            "start_block": 0,
        },
    })
config = {
    "wallet_path": wallet,
    "lightpool_rpc_url": lp_rpc,
    "cast_bin": "cast",
    "local": {"rpc_url": lp_rpc, "chain_id": 1},
    "routes": routes,
}
with open(config_path, "w", encoding="utf-8") as handle:
    json.dump(config, handle, indent=2)
    handle.write("\n")
print(f"wrote {config_path} ({len(routes)} routes)")
PY
}

start_bridge() {
  if is_running bridge; then
    echo "skip  bridge (already running)"
    return
  fi
  if [[ ! -x "$BRIDGE_BIN" ]]; then
    echo "lightpool-bridge not found: $BRIDGE_BIN" >&2
    exit 1
  fi
  echo "start bridge"
  setsid "$BRIDGE_BIN" --config "$BRIDGE_CONFIG" \
    >"$LOG_DIR/bridge.log" 2>&1 < /dev/null &
  echo $! >"$PID_DIR/bridge.pid"
  sleep 2
  if ! is_running bridge; then
    echo "bridge exited; see $LOG_DIR/bridge.log" >&2
    exit 1
  fi
  echo "ok    bridge"
}

lp_available_raw() {
  local token="$1" log available
  log="$LOG_DIR/balance-check.log"
  lp balance --token-address "$token" --account "$MAKER_ADDR" >"$log" 2>&1 || true
  available="$(python3 -c 'import re,sys
text=open(sys.argv[1], errors="replace").read()
match=re.search(r"Available:\s*([0-9]+(?:\.[0-9]+)?)", text)
if not match:
    print("0"); raise SystemExit
text=match.group(1)
if "." in text:
    whole, frac = text.split(".", 1)
    frac = (frac + "000000")[:6]
    print(int(whole) * 1_000_000 + int(frac))
else:
    print(int(text) * 1_000_000)' "$log")"
  printf '%s\n' "$available"
}

deposit_maker_token() {
  local symbol="$1" evm="$2" lp_token="$3"
  local need have raw
  need="$(raw_amount "$MAKER_DEPOSIT_WHOLE")"
  have="$(lp_available_raw "$lp_token")"
  if [[ "$have" -ge "$need" ]]; then
    echo "skip  maker deposit $symbol (already credited)"
    return
  fi
  raw="$need"
  echo "deposit maker $symbol raw=$raw"
  cast send "$evm" "approve(address,uint256)" "$EVM_BRIDGE" "$raw" \
    --rpc-url "$RETH_RPC" --private-key "$MAKER_KEY" >/dev/null
  cast send "$EVM_BRIDGE" "deposit(address,uint64,address)" "$evm" "$raw" "$MAKER_ADDR" \
    --rpc-url "$RETH_RPC" --private-key "$MAKER_KEY" >/dev/null
  local i now
  for i in $(seq 1 45); do
    now="$(lp_available_raw "$lp_token")"
    if [[ "$now" -ge "$need" ]]; then
      echo "ok    maker $symbol credited"
      return
    fi
    sleep 2
  done
  echo "timed out waiting for maker $symbol on LightPool" >&2
  exit 1
}

ensure_backend_bin() {
  if [[ -n "${BACKEND_BIN:-}" ]]; then
    if [[ ! -x "$BACKEND_BIN" ]]; then
      echo "BACKEND_BIN not executable: $BACKEND_BIN" >&2
      exit 1
    fi
    printf '%s\n' "$BACKEND_BIN"
    return
  fi
  need_cmd cargo
  local bin="$APP_DIR/backend/target/release/tokenized-stocks-backend"
  echo "build backend (release)" >&2
  (cd "$APP_DIR/backend" && cargo build --release) >&2
  if [[ ! -x "$bin" ]]; then
    echo "backend binary missing after build: $bin" >&2
    exit 1
  fi
  printf '%s\n' "$bin"
}

start_backend() {
  if [[ ! -f "$APP_DIR/backend/.env" && -f "$APP_DIR/backend/.env.example" ]]; then
    cp "$APP_DIR/backend/.env.example" "$APP_DIR/backend/.env"
  fi
  local bin
  bin="$(ensure_backend_bin)"
  if is_running backend; then
    echo "restart backend (use latest binary)"
    stop_pid backend
    stop_port 3001 backend
  fi
  echo "start backend"
  (
    cd "$APP_DIR/backend"
    setsid "$bin" >"$LOG_DIR/backend.log" 2>&1 < /dev/null &
    echo $! >"$PID_DIR/backend.pid"
  )
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

deposit_maker() {
  echo "=== deposit for maker ==="
  local line symbol evm lp_token
  EVM_BRIDGE="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["evm_bridge"])' "$STATE")"
  while IFS='|' read -r symbol evm lp_token; do
    deposit_maker_token "$symbol" "$evm" "$lp_token"
  done < <(python3 -c 'import json,sys
state=json.load(open(sys.argv[1]))
for token in state["tokens"]:
    print("|".join([token["symbol"], token["evm"], token["lp"]]))' "$STATE")
}

start_all() {
  need_cmd curl
  need_cmd ss
  need_cmd cast
  need_cmd forge
  need_cmd python3
  if [[ ! -x "$LIGHTPOOL_BIN" ]]; then
    echo "lightpool binary not found: $LIGHTPOOL_BIN" >&2
    exit 1
  fi
  mkdirs
  echo "=== start Reth ==="
  start_reth
  echo "=== start LightPool node and indexer ==="
  "$VENUE" start
  setup_tokens_and_markets
  echo "=== map tokens on the bridge ==="
  write_bridge_config
  start_bridge
  deposit_maker
  echo "=== start equity liquidity maker ==="
  start_maker
  echo "=== start backend and frontend ==="
  start_backend
  start_frontend
  wait_http "$APP_API/health" "backend"
  enable_market_orders
  echo
  print_metamask_state
}

enable_market_orders() {
  echo "=== enable market orders on spot markets ==="
  local body code
  body="$(curl -sS -X POST "$APP_API/admin/enable-market-orders" -w "\n%{http_code}" || true)"
  code="$(printf '%s\n' "$body" | tail -n1)"
  body="$(printf '%s\n' "$body" | sed '$d')"
  if [[ "$code" != "200" ]]; then
    echo "warn  enable-market-orders HTTP $code: $body" >&2
    echo "warn  Market tab may fail until allow_market_orders is true on each spot" >&2
    return 0
  fi
  echo "ok    market orders enabled"
  printf '%s\n' "$body"
}

print_metamask_state() {
  echo "Stock deposit stack is up."
  echo "  Reth     $RETH_RPC"
  echo "  Node     $LP_RPC"
  echo "  Indexer  http://127.0.0.1:3002"
  echo "  App      http://127.0.0.1:3000"
  echo "  Maker    $LOG_DIR/maker.log"
  echo "  State    $STATE"
  echo
  echo "Accounts (import into MetaMask)"
  echo "  Validator / maker  (node wallet and funded maker are the same key)"
  echo "    address  $MAKER_ADDR"
  echo "    key      $MAKER_KEY"
  echo "  Demo user"
  echo "    address  $USER_ADDR"
  echo "    key      $USER_KEY"
  if [[ ! -f "$STATE" ]]; then
    echo "MetaMask: state file missing ($STATE)" >&2
    return
  fi
  python3 - "$STATE" "$RETH_RPC" <<'PY'
import json, sys
state = json.load(open(sys.argv[1], encoding="utf-8"))
rpc = sys.argv[2]
print()
print("MetaMask network")
print(f"  RPC URL    {rpc}")
print(f"  Chain ID   {state.get('evm_chain_id')}")
print(f"  Bridge     {state.get('evm_bridge')}")
print("Add these ERC20 tokens in MetaMask (6 decimals):")
for token in state.get("tokens") or []:
    print(f"  {token.get('symbol'):<6} {token.get('evm')}")
PY
}

ensure_maker_bin() {
  if [[ -n "${MAKER_BIN:-}" ]]; then
    if [[ ! -x "$MAKER_BIN" ]]; then
      echo "MAKER_BIN not executable: $MAKER_BIN" >&2
      exit 1
    fi
    printf '%s\n' "$MAKER_BIN"
    return
  fi
  need_cmd cargo
  local bin="$BOT_DIR/target/release/equity-liquidity-maker"
  echo "build equity-liquidity-maker (release)" >&2
  (cd "$BOT_DIR" && cargo build --release -p lightpool-strategies --bin equity-liquidity-maker) >&2
  if [[ ! -x "$bin" ]]; then
    echo "maker binary missing after build: $bin" >&2
    exit 1
  fi
  printf '%s\n' "$bin"
}

start_maker() {
  if [[ ! -f "$WALLET_PATH" ]]; then
    echo "maker wallet missing: $WALLET_PATH" >&2
    exit 1
  fi
  if [[ ! -f "$REGISTRY" ]]; then
    echo "registry missing: $REGISTRY" >&2
    exit 1
  fi
  local bin key
  bin="$(ensure_maker_bin)"
  key="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["private_key"])' "$WALLET_PATH")"
  if is_running maker; then
    echo "restart maker (use latest binary)"
    stop_pid maker
  fi
  echo "start equity-liquidity-maker"
  (
    cd "$BOT_DIR"
    TOKENIZED_STOCKS_REGISTRY="$REGISTRY" \
    LIGHTPOOL_PRIVATE_KEY="$key" \
    setsid "$bin" --symbol AAPL,TSLA,INTC --depth 20 \
      >"$LOG_DIR/maker.log" 2>&1 < /dev/null &
    echo $! >"$PID_DIR/maker.pid"
  )
}

stop_maker() {
  echo "=== stop maker ==="
  stop_pid maker
}

stop_all() {
  need_cmd ss
  stop_maker
  stop_app
  stop_bridge
  stop_reth
  echo "=== stop LightPool node and indexer ==="
  "$VENUE" stop
}

clean_all() {
  local name
  for name in maker frontend backend bridge reth lightpool indexer; do
    if is_running "$name"; then
      echo "services still running; run: $0 stop" >&2
      echo "then: $0 clean" >&2
      exit 1
    fi
  done
  rm -rf "$DATA" "$CONTRACTS/broadcast" "$CONTRACTS/cache"
  echo "cleaned $DATA (Reth, bridge, forge broadcast, registry, course runtime)"
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
