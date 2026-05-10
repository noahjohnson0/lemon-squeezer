#!/usr/bin/env bash
# librarian-cascade — two-model RAG pipeline.
#
# Convention: the harness contract uses a single $model arg, but a cascade
# needs two. We interpret $model as "<retriever>+<answerer>" with literal '+'.
# If '+' is missing, we use $model as the answerer and $CASCADE_RETRIEVER
# (default qwen3:8b) as the retriever.
#
# Examples:
#   bin/eval-run --host 4070 librarian-cascade wiki-rag-tool 'qwen3:8b+command-r:35b' rag
#   CASCADE_RETRIEVER=qwen3:8b bin/eval-run librarian-cascade wiki-rag-tool gpt-oss:20b rag
harness_run() {
  local ws="$1" prompt_file="$2" model="$3" run_dir="$4"; shift 4
  : "${OLLAMA_API_BASE:=http://localhost:11434}"
  local ROOT
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

  local retriever answerer
  if [[ "$model" == *"+"* ]]; then
    retriever="${model%%+*}"
    answerer="${model#*+}"
  else
    retriever="${CASCADE_RETRIEVER:-qwen3:8b}"
    answerer="$model"
  fi

  python3 "$ROOT/bin/librarian_cascade.py" \
    --retriever "$retriever" \
    --answerer "$answerer" \
    --prompt-file "$prompt_file" \
    --workspace "$ws" \
    --run-dir "$run_dir" \
    --base-url "${OLLAMA_API_BASE}/v1" \
    "$@"
}
