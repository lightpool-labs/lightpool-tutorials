# Order book client (clob-index)

Self-contained guide for apps that show a live spot order book.  
**Talk to clob-index only** (`http://127.0.0.1:3002` / `ws://127.0.0.1:3002`). Do **not** go through the app backend for book data. Do **not** require any other sample app repo.

Field shapes: [http.md](http.md) (`GET /api/spot/:spot_market/book`), [ws.md](ws.md) (`orderbook_delta`).

`spot_market` = LightPool spot **ContractAddress** (typically `0x03…`), URL-encoded in the path.

---

## 1. HTTP snapshot (full book)

```http
GET /api/spot/{spot_market}/book?depth=10
```

Default depth 10, clamped 1…50.

Response:

```json
{
  "sequence": 0,
  "bids": [{ "price": "<string>", "size": "<string>" }],
  "asks": [{ "price": "<string>", "size": "<string>" }],
  "last_trade_price": "<string|omit>"
}
```

Bids: best (highest) first. Asks: best (lowest) first.

Example (TypeScript):

```ts
const CLOB_INDEX_URL =
  process.env.NEXT_PUBLIC_CLOB_INDEX_URL ?? "http://127.0.0.1:3002";

type BookLevel = { price: string; size: string };
type BookResponse = {
  sequence: number;
  bids: BookLevel[];
  asks: BookLevel[];
  last_trade_price?: string | null;
};

export async function fetchBookSnapshot(
  spotMarket: string,
  depth = 10,
): Promise<BookResponse> {
  const path = encodeURIComponent(spotMarket);
  const res = await fetch(
    `${CLOB_INDEX_URL}/api/spot/${path}/book?depth=${depth}`,
    { cache: "no-store" },
  );
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(
      (body as { error?: string }).error ?? `book HTTP ${res.status}`,
    );
  }
  return res.json() as Promise<BookResponse>;
}
```

---

## 2. WebSocket subscribe (live)

URL: `ws://127.0.0.1:3002/api/ws`  
(or `NEXT_PUBLIC_CLOB_INDEX_WS_URL`, default `ws://127.0.0.1:3002`, path `/api/ws`).

### Subscribe

```json
{
  "op": "subscribe",
  "channel": "orderbook_delta",
  "spot_market": "<ContractAddress hex>",
  "depth": 10
}
```

### Unsubscribe

```json
{
  "op": "unsubscribe",
  "channel": "orderbook_delta",
  "spot_market": "<ContractAddress hex>"
}
```

### Server messages

After subscribe, expect a **snapshot** then **deltas**.

Snapshot (`type` often `orderbook_snapshot` or a snapshot-like string — treat as full book when bids/asks are complete levels):

```json
{
  "type": "orderbook_snapshot",
  "spot_market": "<string>",
  "sequence": 0,
  "bids": [{ "price": "<string>", "size": "<string>" }],
  "asks": [{ "price": "<string>", "size": "<string>" }],
  "last_trade_price": "<string|omit>"
}
```

Delta (`type` = `orderbook_delta`):

```json
{
  "type": "orderbook_delta",
  "spot_market": "<string>",
  "sequence": 0,
  "block_num": 0,
  "bids": [{ "price": "<string>", "size": "<string>" }],
  "asks": [{ "price": "<string>", "size": "<string>" }],
  "last_trade_price": "<string|omit>"
}
```

**Rule:** on a delta level, `size` `"0"` (or non-finite / zero) means **remove** that price. Otherwise upsert that price.

---

## 3. Apply delta (reference logic)

```ts
function applyLevelChanges(
  levels: BookLevel[],
  changes: BookLevel[],
  sort: (a: string, b: string) => number,
): BookLevel[] {
  const map = new Map(levels.map((l) => [l.price, l.size]));
  for (const change of changes) {
    const n = Number.parseFloat(change.size);
    if (!Number.isFinite(n) || n === 0) {
      map.delete(change.price);
    } else {
      map.set(change.price, change.size);
    }
  }
  return Array.from(map.entries())
    .map(([price, size]) => ({ price, size }))
    .sort((a, b) => sort(a.price, b.price));
}

function trimLevels(levels: BookLevel[], depth: number): BookLevel[] {
  if (depth <= 0 || levels.length <= depth) return levels;
  return levels.slice(0, depth);
}

export function applyOrderBookDelta(
  book: BookResponse,
  delta: {
    sequence: number;
    bids: BookLevel[];
    asks: BookLevel[];
    last_trade_price?: string | null;
  },
  depth = 10,
): BookResponse {
  const comparePriceDesc = (a: string, b: string) =>
    Number.parseFloat(b) - Number.parseFloat(a);
  const comparePriceAsc = (a: string, b: string) =>
    Number.parseFloat(a) - Number.parseFloat(b);

  return {
    sequence: delta.sequence,
    bids: trimLevels(
      applyLevelChanges(book.bids, delta.bids, comparePriceDesc),
      depth,
    ),
    asks: trimLevels(
      applyLevelChanges(book.asks, delta.asks, comparePriceAsc),
      depth,
    ),
    last_trade_price: delta.last_trade_price ?? book.last_trade_price,
  };
}
```

---

## 4. Recommended client flow

```text
Select spot_market (0x03…)
  → GET /book snapshot → render
  → WS subscribe orderbook_delta
  → on snapshot: replace local book
  → on delta: applyOrderBookDelta → render (optional rAF throttle)
Switch market
  → unsubscribe old spot_market
  → clear UI
  → GET + subscribe new spot_market
Unmount
  → unsubscribe + close socket
```

Optional: skip the initial GET and wait for the first WS snapshot; GET first is clearer and shows data even if WS is slow.

Throttle UI updates with `requestAnimationFrame` so high-frequency deltas do not flood React.

---

## 5. Env

```text
NEXT_PUBLIC_CLOB_INDEX_URL=http://127.0.0.1:3002
NEXT_PUBLIC_CLOB_INDEX_WS_URL=ws://127.0.0.1:3002
```

---

## 6. Do not

- Do not proxy the book through the app backend for this tutorial pattern.
- Do not use Hyperliquid L2 as the LightPool order book UI source (that is for a separate liquidity-maker step).
- Do not invent message field names; prefer this doc + [http.md](http.md) / [ws.md](ws.md).
