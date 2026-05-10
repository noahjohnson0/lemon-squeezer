#!/usr/bin/env bash
# squeezer-ensemble harness: N models race in parallel sub-workspaces, judge picks the winner.
#
# The "model" arg passed to eval-run is a comma-separated list of candidate models.
# JUDGE defaults to the first primary; set $SQ_JUDGE_MODEL to override.
harness_run() {
  local ws="$1" prompt_file="$2" model="$3" run_dir="$4"; shift 4
  : "${OLLAMA_API_BASE:=http://localhost:11434}"
  local JUDGE="${SQ_JUDGE_MODEL:-${model%%,*}}"
  local ROOT
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  python3 "$ROOT/bin/squeezer_pipeline.py" \
    --workspace "$ws" \
    --run-dir "$run_dir" \
    --prompt-file "$prompt_file" \
    --base-url "${OLLAMA_API_BASE}/v1" \
    --pipeline ensemble \
    --primary-model "$model" \
    --judge-model "$JUDGE" \
    "$@"
}
