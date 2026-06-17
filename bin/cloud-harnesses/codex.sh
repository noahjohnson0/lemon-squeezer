#!/usr/bin/env bash
# Cloud-harness adapter: OpenAI Codex CLI (`codex exec`). See ./README.md.
# Codex runs on its OWN OpenAI auth (already configured on this box), NOT
# OpenRouter - so the <model_slug> arg is just a label; codex uses its default
# model. (Set CODEX_MODEL to force one.) host/cost are OpenAI-native.
#   argv: <ws> <prompt_file> <model_slug> <run_dir> <base_url>
#   writes into <run_dir>: tokens_in tokens_out tool_calls cost
set -uo pipefail
ws="$1"; prompt_file="$2"; slug="$3"; run_dir="$4"; base_url="${5:-}"

export BROWSER="${BROWSER:-true}"
codex_bin="$(command -v codex || echo "$HOME/AppData/Roaming/npm/codex")"
prompt="$(cat "$prompt_file")"

# workspace-write lets it edit files; --skip-git-repo-check because the eval
# workspace isn't a git repo; </dev/null so codex doesn't block reading stdin.
model_flag=(); [ -n "${CODEX_MODEL:-}" ] && model_flag=(-m "$CODEX_MODEL")
out="$( "$codex_bin" exec -C "$ws" -s workspace-write --skip-git-repo-check \
    ${model_flag[@]+"${model_flag[@]}"} "$prompt" < /dev/null 2>&1 )"
printf '%s\n' "$out" | tee "$run_dir/harness.log"

# codex prints a "tokens used N" summary; it doesn't report USD, so cost stays 0.
python3 - "$run_dir/harness.log" "$run_dir" <<'PY'
import os, re, sys
log = open(sys.argv[1], encoding="utf-8", errors="replace").read()
rd = sys.argv[2]
m = re.findall(r"tokens used\s*([\d,]+)", log, re.I)
tot = int(m[-1].replace(",", "")) if m else 0
for n, v in (("tokens_in", 0), ("tokens_out", tot), ("tool_calls", 0), ("cost", "0")):
    open(os.path.join(rd, n), "w").write(str(v))
PY
