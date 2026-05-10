#!/usr/bin/env bash
# qa harness: single-turn LLM call for factuality / RAG / knowledge evals.
# No tools, no agent loop. Writes the model's response to workspace/answer.txt;
# the eval's rubric.sh reads that file and scores it.
harness_run() {
  local ws="$1" prompt_file="$2" model="$3" run_dir="$4"; shift 4
  : "${OLLAMA_API_BASE:=http://localhost:11434}"
  local ROOT
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  python3 "$ROOT/bin/qa.py" \
    --model "$model" \
    --prompt-file "$prompt_file" \
    --workspace "$ws" \
    --run-dir "$run_dir" \
    --base-url "${OLLAMA_API_BASE}/v1" \
    "$@"
}
