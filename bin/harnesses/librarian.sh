#!/usr/bin/env bash
# librarian — RAG agent harness. See bin/librarian.py.
#
# Honors $LEMON_CORPORA (colon-separated name=path) and $LEMON_ALLOW_WEB.
harness_run() {
  local ws="$1" prompt_file="$2" model="$3" run_dir="$4"; shift 4
  : "${OLLAMA_API_BASE:=http://localhost:11434}"
  local ROOT
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

  local extra=()
  if [[ "${LEMON_ALLOW_WEB:-0}" == "1" ]]; then
    extra+=(--allow-web)
  fi

  python3 "$ROOT/bin/librarian.py" \
    --model "$model" \
    --prompt-file "$prompt_file" \
    --workspace "$ws" \
    --run-dir "$run_dir" \
    --base-url "${OLLAMA_API_BASE}/v1" \
    "${extra[@]}" \
    "$@"
}
