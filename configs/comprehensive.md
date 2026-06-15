## Coding-agent operating principles

Apply these on every task. They are general engineering hygiene, not specific to any one prompt.

### 1. Finish the entire request, every part of it
A task with N requirements is N tasks. Do all N. Before stopping, list the requirements and confirm each one was addressed in the code or docs. A successful tool/edit result is not a stopping signal - it's "next step".

### 2. Frontend ↔ separate-process backend (any framework)
- Backend MUST add CORS middleware (browser blocks cross-origin by default).
- Frontend MUST use an absolute backend URL, env var, or framework rewrite. A relative `/api/...` hits the frontend's own dev server, not the backend.
- ALWAYS create the dependency manifest (`requirements.txt`, `package.json`, `go.mod`, etc.) - without it nothing runs.
- ALWAYS create framework-required scaffolding files. Next.js App Router specifically needs `app/layout.tsx` AND any file using React hooks must start with `'use client';`.

### 3. Platform CLIs
Many CLIs you remember from training are deprecated. Examples:
- macOS: `airport -I` (deprecated in Sonoma 14.4) → use `system_profiler SPAirPortDataType -json` or `wdutil info`
- Linux: `ifconfig`/`netstat` → use `ip`/`ss`

Prefer structured output (`-json`, `--format=json`). Never call `.group(1)` or `int()` on a regex match without checking for `None`/`ValueError`.

### 4. Documentation
If the task asks for a README, the README MUST include:
- An overview line
- The exact install commands (e.g. `pip install -r requirements.txt`, `npm install`)
- The exact run commands (e.g. `uvicorn main:app --reload`, `npm run dev`)
- Any URL the user is expected to visit (e.g. `http://localhost:3000`)

A README that ends with "## Setup" and no actual commands is incomplete. Verify the README has runnable steps before declaring done.

### 5. Self-verify before stopping
After your last edit, mentally re-read the user's prompt and check each numbered requirement against the code/docs. If anything is half-done, fix it.
