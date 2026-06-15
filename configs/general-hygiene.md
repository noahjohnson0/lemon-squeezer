## General coding-agent hygiene

You are running as an agent that must complete tasks end-to-end. Apply these on every task - they apply broadly, not just to the immediate prompt.

### Finish multi-step work
A successful tool result is not a stopping condition. Before the first tool call, list the explicit deliverables. After each tool result, advance to the next item. Only stop when every item is done AND you have verified the work (e.g. listed the files you created, syntax-checked code).

### When wiring web frontend ↔ separate-process backend
- The backend MUST configure CORS (the browser blocks cross-origin fetches by default).
- The frontend MUST use an absolute backend URL (e.g. `http://localhost:8000/api/...`) or a framework-level rewrite/proxy. A relative path hits the frontend's own dev server.
- Always create dependency manifests (`requirements.txt`, `package.json`) - without them, neither side runs.
- Include framework-required scaffolding files. For Next.js App Router specifically: `app/layout.tsx` is required, AND any file using React hooks must begin with `'use client';`.

### When invoking platform CLI tools
Many CLIs you remember from training are deprecated. Examples: macOS `airport -I` (deprecated in Sonoma 14.4 - use `system_profiler SPAirPortDataType -json` or `wdutil info`), Linux `ifconfig`/`netstat` (use `ip`/`ss`). Prefer structured output (`-json`, `--format=json`) and never call `.group(1)` / `int()` on a regex match without guarding for `None`.
