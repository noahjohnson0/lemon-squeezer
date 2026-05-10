#!/usr/bin/env bash
# squeezer harness: our minimal raw-tools harness. Direct /v1/chat/completions with read/write/list/bash tools.
harness_run() {
  local ws="$1" prompt_file="$2" model="$3" run_dir="$4"; shift 4
  : "${OLLAMA_API_BASE:=http://localhost:11434}"
  python3 "$HOME/repos/lemon-squeezer/bin/squeezer.py" \
    --model "$model" \
    --prompt-file "$prompt_file" \
    --workspace "$ws" \
    --run-dir "$run_dir" \
    --base-url "${OLLAMA_API_BASE}/v1" \
    "$@"
}
