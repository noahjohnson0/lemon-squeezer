#!/usr/bin/env bash
# Cloud-harness adapter: Cline CLI (`clite`, from @cline/cli) against OpenRouter.
# See ./README.md. Note: cline expects models fluent in its XML tool-call format,
# so weaker models tend to score poorly (this is a real harness property).
#   argv: <ws> <prompt_file> <model_slug> <run_dir> <base_url>
#   env:  LEMON_API_KEY (OpenRouter bearer)
#   writes into <run_dir>: tokens_in tokens_out tool_calls cost
set -uo pipefail
ws="$1"; prompt_file="$2"; slug="$3"; run_dir="$4"; base_url="${5:-}"

export BROWSER="${BROWSER:-true}"
key="${LEMON_API_KEY:?LEMON_API_KEY required}"
clite_bin="$(command -v clite || echo "$HOME/AppData/Roaming/npm/clite")"
prompt="$(cat "$prompt_file")"

# Default mode is act + auto-approve (non-interactive). --data-dir isolates state
# per run so parallel matrix cells don't share one ~/.cline. cline's own -t does
# NOT reliably stop it (it hung 40 min on bloom-filter once), so wrap in a HARD
# external timeout - on expiry the cell just scores low/0, never jams the pool.
TO="$(command -v timeout || command -v gtimeout || true)"
${TO:+$TO 420} "$clite_bin" -P openrouter -k "$key" -m "$slug" -c "$ws" \
    --data-dir "$run_dir/.cline" -t 360 --json "$prompt" 2>&1 | tee "$run_dir/harness.log"

# Counters from cline's --json stream. Cumulative usage lives on the final
# run_result and on agent_event usage events (camelCase: inputTokens/outputTokens/
# totalCost); tool calls are summed from iteration_end.toolCallCount.
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
    ev = d.get("event") if isinstance(d.get("event"), dict) else {}
    if t == "run_result":
        u = d.get("usage") or {}
        ti = max(ti, int(u.get("inputTokens", 0) or 0))
        to = max(to, int(u.get("outputTokens", 0) or 0))
        cost = max(cost, float(u.get("totalCost", 0) or 0))
    if ev.get("type") == "usage":
        ti = max(ti, int(ev.get("totalInputTokens", 0) or 0))
        to = max(to, int(ev.get("totalOutputTokens", 0) or 0))
        cost = max(cost, float(ev.get("totalCost", 0) or 0))
    if ev.get("type") == "iteration_end":
        tc += int(ev.get("toolCallCount", 0) or 0)
for n, v in (("tokens_in", ti), ("tokens_out", to), ("tool_calls", tc), ("cost", "%.6f" % cost)):
    open(os.path.join(rd, n), "w").write(str(v))
PY
