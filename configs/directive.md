## Directive: complete every requirement explicitly

The user prompt has multiple numbered requirements. Read them carefully. Before writing any code, list each requirement and one specific implementation choice for it.

For multi-component web apps:
- Backend MUST set CORS headers if a separate frontend will fetch from it.
- Frontend MUST use absolute or proxied URLs (relative paths hit the wrong server).
- Frontend hooks (useState/useEffect) require `'use client';` as the first non-empty line in App Router files.
- Always create `frontend/app/layout.tsx` for Next.js App Router.
- Always create `frontend/package.json` with the framework deps and a "dev" script.
- Always create `backend/requirements.txt`.

For platform CLIs, prefer modern replacements (`system_profiler -json` not `airport`; `ip` not `ifconfig`) and structured output. Guard regex extraction with try/except or None checks; never call `.group(1)` unconditionally.

After writing files, do `ls -R` to verify nothing's missing. If any requirement is unmet, fix it before stopping.
