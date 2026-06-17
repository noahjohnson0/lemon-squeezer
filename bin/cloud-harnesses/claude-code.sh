#!/usr/bin/env bash
# Cloud-harness adapter: Anthropic Claude Code (`claude -p`). See ./README.md.
# Runs on its OWN Anthropic auth (already configured), NOT OpenRouter. The
# <model_slug> is passed as a Claude model alias (e.g. "sonnet", "opus").
#   argv: <ws> <prompt_file> <model_slug> <run_dir> <base_url>
#   writes into <run_dir>: tokens_in tokens_out tool_calls cost
set -uo pipefail
ws="$1"; prompt_file="$2"; slug="$3"; run_dir="$4"; base_url="${5:-}"

export BROWSER="${BROWSER:-true}"
claude_bin="$(command -v claude || echo "$HOME/AppData/Roaming/npm/claude")"
prompt="$(cat "$prompt_file")"

# -p = headless; json output carries usage + total_cost_usd; skip-permissions so
# it can write files unattended. Runs with cwd = workspace.
model_flag=(); [ -n "$slug" ] && model_flag=(--model "$slug")
out="$( cd "$ws" && "$claude_bin" -p "$prompt" --output-format json \
    --dangerously-skip-permissions ${model_flag[@]+"${model_flag[@]}"} < /dev/null 2>&1 )"
printf '%s\n' "$out" | tee "$run_dir/harness.log"

# claude -p --output-format json emits one JSON object with usage + total_cost_usd.
python3 - "$run_dir/harness.log" "$run_dir" <<'PY'
import json, os, re, sys
raw = open(sys.argv[1], encoding="utf-8", errors="replace").read()
rd = sys.argv[2]
ti = to = tc = 0
cost = 0.0
m = re.search(r"\{[\s\S]+\}\s*$", raw)  # trailing JSON object
if m:
    try:
        d = json.loads(m.group(0))
        u = d.get("usage") or {}
        ti = int(u.get("input_tokens", 0) or 0) + int(u.get("cache_read_input_tokens", 0) or 0)
        to = int(u.get("output_tokens", 0) or 0)
        cost = float(d.get("total_cost_usd", 0) or 0)
        tc = int(d.get("num_turns", 0) or 0)
    except Exception:
        pass
for n, v in (("tokens_in", ti), ("tokens_out", to), ("tool_calls", tc), ("cost", "%.6f" % cost)):
    open(os.path.join(rd, n), "w").write(str(v))
PY
