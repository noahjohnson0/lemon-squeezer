#!/usr/bin/env bash
# squeezer-tdd: TDD-style agent loop. Same tools as squeezer, system prompt forces
# tests-first discipline. The agent writes a test_*.py, runs it, iterates until green.
harness_run() {
  local ws="$1" prompt_file="$2" model="$3" run_dir="$4"; shift 4
  : "${OLLAMA_API_BASE:=http://localhost:11434}"
  local ROOT
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  python3 "$ROOT/bin/squeezer.py" \
    --model "$model" \
    --prompt-file "$prompt_file" \
    --workspace "$ws" \
    --run-dir "$run_dir" \
    --base-url "${OLLAMA_API_BASE}/v1" \
    --system "@$ROOT/configs/system-prompts/tdd.md" \
    --max-iter 30 \
    "$@"
}
