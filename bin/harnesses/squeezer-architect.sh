#!/usr/bin/env bash
# squeezer-architect: 2-model planner→executor pipeline.
# The "model" arg passed to eval-run is the EXECUTOR.
# The ARCHITECT (planner) defaults to gpt-oss:20b — strongest faultfinder/planner in our matrix.
# Override via $SQ_ARCHITECT_MODEL.
harness_run() {
  local ws="$1" prompt_file="$2" model="$3" run_dir="$4"; shift 4
  : "${OLLAMA_API_BASE:=http://localhost:11434}"
  local ARCH="${SQ_ARCHITECT_MODEL:-gpt-oss:20b}"
  local ROOT
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  python3 "$ROOT/bin/squeezer_pipeline.py" \
    --workspace "$ws" \
    --run-dir "$run_dir" \
    --prompt-file "$prompt_file" \
    --base-url "${OLLAMA_API_BASE}/v1" \
    --pipeline architect \
    --primary-model "$model" \
    --architect-model "$ARCH" \
    "$@"
}
