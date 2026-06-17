#!/usr/bin/env bash
# Cloud-harness adapter: opencode (SST) against an OpenRouter model. See ./README.md.
#   argv: <ws> <prompt_file> <model_slug> <run_dir> <base_url>
#   env:  LEMON_API_KEY (OpenRouter bearer)
#   writes into <run_dir>: tokens_in tokens_out tool_calls cost
set -uo pipefail
ws="$1"; prompt_file="$2"; slug="$3"; run_dir="$4"; base_url="${5:-}"

export OPENROUTER_API_KEY="${LEMON_API_KEY:?LEMON_API_KEY required}"
export BROWSER="${BROWSER:-true}"
oc="$(command -v opencode || echo "$HOME/AppData/Roaming/npm/opencode")"
prompt="$(cat "$prompt_file")"

# opencode run is non-interactive; --format json streams step/tool/usage events.
out="$( "$oc" run --dir "$ws" -m "openrouter/$slug" --format json "$prompt" 2>&1 )"
printf '%s\n' "$out" | tee "$run_dir/harness.log"

# Counters from the JSON event stream: tokens + cost live on step_finish parts;
# tool_use events are file/tool calls.
python3 - "$run_dir/harness.log" "$run_dir" <<'PY'
import json, os, sys
rd = sys.argv[2]
ti = to = tc = 0
cost = 0.0
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        d = json.loads(line)
    except Exception:
        continue
    t = d.get("type")
    part = d.get("part") if isinstance(d.get("part"), dict) else {}
    if t == "tool_use":
        tc += 1
    if t == "step_finish":
        tok = part.get("tokens") or {}
        ti += tok.get("input", 0) or 0
        to += tok.get("output", 0) or 0
        c = part.get("cost")
        if isinstance(c, (int, float)):
            cost += c
for n, v in (("tokens_in", ti), ("tokens_out", to), ("tool_calls", tc), ("cost", "%.6f" % cost)):
    open(os.path.join(rd, n), "w").write(str(v))
PY
