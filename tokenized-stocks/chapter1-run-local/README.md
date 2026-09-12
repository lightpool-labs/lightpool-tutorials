# Tokenized stocks — Chapter 1: run local

**Status:** scaffold only. Prompts and `run-local.sh` are not written yet.

**Goal (planned):** start a local LightPool node + clob-index, create USDT + AAPL tokens and an `AAPL/USDT` spot market, and verify the book over clob-index (`:3002`). No event-contract UI, bot, or bridge.

## Before you start

Agents: read [`../../AGENTS.md`](../../AGENTS.md), [`../../common/glossary.md`](../../common/glossary.md), [`../../common/architecture.md`](../../common/architecture.md), and [`../../skills/spot-lightpool/SKILL.md`](../../skills/spot-lightpool/SKILL.md).

This track is **spot only** (base/quote CLOB). Do not bootstrap Polymarket / YES-NO event markets here.

## Planned steps (not implemented)

1. Clone `lightpool-node` and `lightpool-clob-indexer`
2. Install toolchain (Rust, etc.)
3. Build `lightpool` + clob-index
4. Start node + indexer; create tokens and spot market; verify with curl against `:3002`

Until this chapter is filled in, use the architecture doc and the frozen skill API; do not invent a run script.
