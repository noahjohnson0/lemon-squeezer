#!/usr/bin/env bash
# squeezer-critique harness: 2-model draft → critique → refine pipeline.
#
# The "model" arg passed to eval-run is the PRIMARY (drafter+refiner).
# The CRITIC defaults to gpt-oss:20b (we found it the best at faultfinding)
# but can be overridden via $SQ_CRITIC_MODEL.
harness_run() {
  local ws="$1" prompt_file="$2" model="$3" run_dir="$4"; shift 4
  : "${OLLAMA_API_BASE:=http://localhost:11434}"
  local CRITIC="${SQ_CRITIC_MODEL:-gpt-oss:20b}"
  local ROUNDS="${SQ_CRITIQUE_ROUNDS:-1}"
  local ROOT
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  python3 "$ROOT/bin/squeezer_pipeline.py" \
    --workspace "$ws" \
    --run-dir "$run_dir" \
    --prompt-file "$prompt_file" \
    --base-url "${OLLAMA_API_BASE}/v1" \
    --pipeline critique \
    --primary-model "$model" \
    --critic-model "$CRITIC" \
    --rounds "$ROUNDS" \
    "$@"
}
