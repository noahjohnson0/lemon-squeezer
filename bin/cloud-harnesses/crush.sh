#!/usr/bin/env bash
# Cloud-harness adapter: Charm's crush against an OpenRouter model. See ./README.md.
#   argv: <ws> <prompt_file> <model_slug> <run_dir> <base_url>
#   env:  LEMON_API_KEY (OpenRouter bearer)
#   writes into <run_dir>: tokens_in tokens_out tool_calls cost
set -uo pipefail
ws="$1"; prompt_file="$2"; slug="$3"; run_dir="$4"; base_url="${5:-}"

export OPENROUTER_API_KEY="${LEMON_API_KEY:?LEMON_API_KEY required}"
export BROWSER="${BROWSER:-true}"
crush_bin="$(command -v crush || echo "$HOME/AppData/Roaming/npm/crush")"
prompt="$(cat "$prompt_file")"

# `crush run` is non-interactive and auto-accepts file writes (no --yolo needed -
# that flag only applies to the interactive TUI). -c sets the working dir, so its
# .crush session store stays inside the per-run workspace (isolated).
"$crush_bin" run -q -c "$ws" -m "openrouter/$slug" "$prompt" 2>&1 | tee "$run_dir/harness.log"

# crush doesn't print structured usage to stdout, so tokens/cost aren't captured
# here (cost will read as 0 on the leaderboard - a known limitation of this
# adapter; the rubric score is the real signal). tool_calls left 0 too.
for n in tokens_in tokens_out tool_calls cost; do echo 0 > "$run_dir/$n"; done
