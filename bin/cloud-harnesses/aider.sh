#!/usr/bin/env bash
# Cloud-harness adapter: aider against an OpenAI-compatible endpoint (OpenRouter).
# This mirrors cloud-run's built-in aider branch, proving the generic adapter
# path produces the same result. See ./README.md for the contract.
#   argv: <ws> <prompt_file> <model_slug> <run_dir> <base_url>
#   env:  LEMON_API_KEY (bearer for the endpoint)
#   writes into <run_dir>: tokens_in tokens_out tool_calls cost
set -uo pipefail
ws="$1"; prompt_file="$2"; slug="$3"; run_dir="$4"; base_url="${5:-https://openrouter.ai/api/v1}"

export OPENROUTER_API_KEY="${LEMON_API_KEY:?LEMON_API_KEY required}"
export BROWSER="${BROWSER:-true}"   # never pop a real browser tab on the host
aider_bin="$(command -v aider || echo "$HOME/.local/bin/aider.exe")"
prompt="$(cat "$prompt_file")"

# Starter files already in the workspace become aider's editable file list.
mapfile -t starter < <(cd "$ws" && find . -type f -not -path './.git/*' | sed 's|^\./||')

out="$( cd "$ws" && "$aider_bin" --model "openrouter/$slug" \
    --yes-always --no-auto-commits --no-stream --no-pretty --no-analytics \
    --no-show-model-warnings --no-git --no-check-update \
    ${starter[@]+"${starter[@]}"} --message "$prompt" 2>&1 )"
printf '%s\n' "$out" | tee "$run_dir/harness.log"   # stdout -> cloud-run's stdout.log

# Counters: aider prints "Tokens: N sent, M received" and "Cost: $X ... $Y session".
python3 - "$run_dir/harness.log" "$run_dir" <<'PY'
import os, re, sys
log = open(sys.argv[1], encoding="utf-8", errors="replace").read(); rd = sys.argv[2]
ti = sum(int(x.replace(",", "")) for x in re.findall(r"Tokens:\s*([\d,]+)\s*sent", log))
to = sum(int(x.replace(",", "")) for x in re.findall(r"sent,\s*([\d,]+)\s*received", log))
sess = re.findall(r"\$\s*([0-9.]+)\s*session", log)
msg  = re.findall(r"Cost:\s*\$\s*([0-9.]+)\s*message", log)
cost = float(sess[-1]) if sess else (sum(float(x) for x in msg) if msg else 0.0)
for n, v in (("tokens_in", ti), ("tokens_out", to), ("tool_calls", 0), ("cost", "%.6f" % cost)):
    open(os.path.join(rd, n), "w").write(str(v))
PY
