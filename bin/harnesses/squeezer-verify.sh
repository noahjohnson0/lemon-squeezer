#!/usr/bin/env bash
# squeezer-verify: single-model TDD/property-test loop. Agent writes impl + property tests
# in the same session, runs pytest, fixes until green.
harness_run() {
  local ws="$1" prompt_file="$2" model="$3" run_dir="$4"; shift 4
  : "${OLLAMA_API_BASE:=http://localhost:11434}"
  local ROOT
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  python3 "$ROOT/bin/squeezer_pipeline.py" \
    --workspace "$ws" \
    --run-dir "$run_dir" \
    --prompt-file "$prompt_file" \
    --base-url "${OLLAMA_API_BASE}/v1" \
    --pipeline verify \
    --primary-model "$model" \
    "$@"
}
