#!/usr/bin/env bash
# Cloud-harness adapter: pi (@earendil-works/pi-coding-agent) against OpenRouter.
# pi has a native openrouter provider and reads OPENROUTER_API_KEY. See ./README.md.
#   argv: <ws> <prompt_file> <model_slug> <run_dir> <base_url>
#   env:  LEMON_API_KEY (OpenRouter bearer)
#   writes into <run_dir>: tokens_in tokens_out tool_calls cost
set -uo pipefail
ws="$1"; prompt_file="$2"; slug="$3"; run_dir="$4"; base_url="${5:-}"

export OPENROUTER_API_KEY="${LEMON_API_KEY:?LEMON_API_KEY required}"
export BROWSER="${BROWSER:-true}"
pi_bin="$(command -v pi || echo "$HOME/AppData/Roaming/npm/pi")"
prompt="$(cat "$prompt_file")"

# -p = non-interactive; --mode json streams events. Do NOT pass --thinking off:
# some OpenRouter models (e.g. gpt-oss) reject disabled reasoning with a 400.
out="$( cd "$ws" && "$pi_bin" --model "openrouter/$slug" --mode json -p "$prompt" 2>&1 )"
printf '%s\n' "$out" | tee "$run_dir/harness.log"

# Counters from pi's --mode json events: tool_calls = tool_execution_start events
# (top-level); tokens = max usage found (cumulative final). pi doesn't surface
# OpenRouter cost, so cost stays 0 (documented limitation).
python3 - "$run_dir/harness.log" "$run_dir" <<'PY'
import json, os, sys
rd = sys.argv[2]
ti = to = tc = 0
def find_usage(o):
    global ti, to
    if isinstance(o, dict):
        u = o.get("usage") if isinstance(o.get("usage"), dict) else None
        if u:
            ti = max(ti, int(u.get("input", u.get("prompt_tokens", 0)) or 0))
            to = max(to, int(u.get("output", u.get("completion_tokens", 0)) or 0))
        for v in o.values():
            find_usage(v)
    elif isinstance(o, list):
        for v in o:
            find_usage(v)
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        d = json.loads(line)
    except Exception:
        continue
    if d.get("type") == "tool_execution_start":
        tc += 1
    find_usage(d)
for n, v in (("tokens_in", ti), ("tokens_out", to), ("tool_calls", tc), ("cost", "0")):
    open(os.path.join(rd, n), "w").write(str(v))
PY
