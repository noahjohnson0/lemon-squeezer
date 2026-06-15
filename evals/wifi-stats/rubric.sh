#!/usr/bin/env bash
# Score a wifi-stats workspace. Usage: rubric.sh <workspace-dir>
# Always evaluates ALL checks - missing files mark dependent checks as fail (0)
# so denominators are constant across runs and scores are comparable.
set -u
WS="${1:?workspace dir required}"
[[ -d "$WS" ]] || { echo "{\"error\":\"workspace not found: $WS\"}"; exit 1; }

declare -a checks
add() { # add <name> <pass:0|1> <weight> <note>
  local n="$1" p="$2" w="$3" note="${4:-}"
  # Normalize: anything non-1 becomes 0
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

# Resolve actual files (any .py in backend/, any page.* in frontend/app/)
B="$(ls "$WS"/backend/*.py 2>/dev/null | head -1 || true)"
F=""
for cand in "$WS/frontend/app/page.tsx" "$WS/frontend/app/page.jsonx" "$WS/frontend/app/page.jsx" "$WS/frontend/app/page.js"; do
  [[ -f "$cand" ]] && F="$cand" && break
done
R="$WS/README.md"

# ---- file presence (always evaluated) ----
add "file:backend/*.py"          "$([[ -n "$B" ]] && echo 1 || echo 0)"     5
add "file:frontend/app/page"     "$([[ -n "$F" ]] && echo 1 || echo 0)"     5
add "file:README.md"             "$([[ -f "$R" ]] && echo 1 || echo 0)"     3

# ---- backend quality (always evaluated; 0 if no backend file) ----
backend_check() {
  local pat="$1"
  [[ -n "$B" ]] && grep -qE "$pat" "$B" && echo 1 || echo 0
}
add "backend:cors_configured"    "$(backend_check 'CORSMiddleware')"        8 "browser fetch from :3000 needs CORS"
add "backend:uses_modern_wifi_cmd" "$(backend_check 'wdutil|system_profiler')" 6 "airport -I deprecated in Sonoma+"
add "backend:correct_endpoint"   "$(backend_check '@app\.get\([\"\x27]/api/wifi[\"\x27]')" 4
if [[ -n "$B" ]]; then
  python3 -m py_compile "$B" 2>/dev/null && add "backend:python_compiles" 1 8 || add "backend:python_compiles" 0 8
else
  add "backend:python_compiles" 0 8
fi
# Guarded regex: either no .group(1) usage OR there's try/except/None-check around it
if [[ -z "$B" ]]; then
  add "backend:guarded_regex" 0 4 "no backend file"
elif ! grep -qE '\.group\(1\)' "$B"; then
  add "backend:guarded_regex" 1 4 "no unguarded .group(1)"
elif grep -qE 'try:|if .*search|or None|\?\?' "$B"; then
  add "backend:guarded_regex" 1 4 "guarded"
else
  add "backend:guarded_regex" 0 4 "unguarded .group(1)"
fi

# ---- frontend quality (always evaluated) ----
frontend_check() {
  local pat="$1"
  [[ -n "$F" ]] && grep -qE "$pat" "$F" && echo 1 || echo 0
}
# 'use client' must be on the first non-empty line
use_client_pass=0
if [[ -n "$F" ]]; then
  first_real_line="$(grep -m1 -vE '^[[:space:]]*$' "$F" || true)"
  [[ "$first_real_line" =~ ^[\'\"]use\ client[\'\"] ]] && use_client_pass=1
fi
add "frontend:use_client_directive" "$use_client_pass" 8 "App Router needs 'use client' for hooks"
add "frontend:polls_every_3s"       "$(frontend_check 'setInterval\([^,]+,[[:space:]]*3000\)')" 4
# Absolute or proxied fetch
fetch_pass=0
if [[ -n "$F" ]]; then
  if grep -qE 'localhost:8000|127\.0\.0\.1:8000|process\.env\.' "$F"; then
    fetch_pass=1
  elif [[ -f "$WS/frontend/next.config.js" ]] && grep -q 'rewrites' "$WS/frontend/next.config.js"; then
    fetch_pass=1
  fi
fi
add "frontend:absolute_or_proxied_fetch" "$fetch_pass" 6 "relative /api/wifi hits Next, not FastAPI"
add "frontend:package_json"  "$([[ -f "$WS/frontend/package.json" ]] && echo 1 || echo 0)" 5
add "frontend:layout_tsx"    "$([[ -f "$WS/frontend/app/layout.tsx" || -f "$WS/frontend/app/layout.jsx" ]] && echo 1 || echo 0)" 4 "App Router requires root layout"

# ---- readme ----
readme_check() {
  local pat="$1"
  [[ -f "$R" ]] && grep -qiE "$pat" "$R" && echo 1 || echo 0
}
add "readme:python_install" "$(readme_check 'pip install|requirements')" 2
add "readme:node_install"   "$(readme_check 'npm install|pnpm install|yarn')" 2

# ---- emit JSON ----
total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in "${checks[@]}"; do
    IFS=$'\t' read -r name pass weight note <<<"$c"
    total=$((total+weight))
    [[ "$pass" == "1" ]] && gained=$((gained+weight))
    [[ $first -eq 0 ]] && printf ',\n'
    printf '    {"name":"%s","pass":%s,"weight":%s,"note":"%s"}' "$name" "$pass" "$weight" "$note"
    first=0
  done
  printf '\n  ],\n'
  pct=0
  [[ $total -gt 0 ]] && pct=$(( (gained * 100) / total ))
  printf '  "gained": %s,\n  "total": %s,\n  "score_pct": %s\n}\n' "$gained" "$total" "$pct"
}
