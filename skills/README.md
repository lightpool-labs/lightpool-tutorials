# Frozen clob-index API

Copy of the spot-lightpool skill (HTTP, WS, tx-submit). Agents must use these shapes; do not invent fields.

| File | Contents |
|------|----------|
| [spot-lightpool/SKILL.md](spot-lightpool/SKILL.md) | When to use, types, agent rules |
| [spot-lightpool/http.md](spot-lightpool/http.md) | HTTP routes and JSON |
| [spot-lightpool/ws.md](spot-lightpool/ws.md) | WebSocket channels and messages |
| [spot-lightpool/tx-submit.md](spot-lightpool/tx-submit.md) | `POST /api/tx/submit` and lightpool-sdk signing |
| [spot-lightpool/orderbook-client.md](spot-lightpool/orderbook-client.md) | Book snapshot + WS delta client (self-contained) |

Both tracks (event contract and tokenized stocks) talk to this clob-index API.
