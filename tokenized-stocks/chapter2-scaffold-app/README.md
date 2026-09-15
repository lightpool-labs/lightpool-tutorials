# Tokenized stocks — Chapter 2: Scaffold app

**Goal:** Create the sample repo `tokenized-stocks-app` (frontend + thin backend). Placeholders and trade layout come in chapter 3.

**Agents:** read [`../../AGENTS.md`](../../AGENTS.md), then paste the prompt below. Detailed instructions are in [`../../prompts/tokenized-stocks-app-02-scaffold.txt`](../../prompts/tokenized-stocks-app-02-scaffold.txt).

**Layout reference:** [`../tokenized-stocks-video-by-chapter.md`](../tokenized-stocks-video-by-chapter.md) (step 2).

## Prompt (copy to your AI)

```text
Please read lightpool-tutorials/prompts/tokenized-stocks-app-02-scaffold.txt and help me create the scaffold app. The name should be tokenized-stocks-app.
```

## Verify

- Repo exists at `lightpool-labs/tokenized-stocks-app/` with `backend/` and `frontend/`
- Backend: `GET http://127.0.0.1:3001/api/health` → `{ "status": "ok" }`
- Frontend: `http://127.0.0.1:3000` shows the scaffold home page
