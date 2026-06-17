#!/usr/bin/env bash
# aider harness: runs aider non-interactively against remote Ollama.
# Token/tool counts come from aider's chat history file (.aider.chat.history.md).
harness_run() {
  local ws="$1" prompt_file="$2" model="$3" run_dir="$4"; shift 4

  export OLLAMA_API_BASE="${OLLAMA_API_BASE:-http://localhost:11434}"
  # --yes-always (below) auto-confirms aider's "open this URL?" prompts, which pops
  # a real browser tab on the host when a model hits a token limit. A no-op BROWSER
  # stops webbrowser.open() from ever launching one.
  export BROWSER="${BROWSER:-true}"
  # Aider's recommended prefix for ollama is "ollama_chat/"
  local aider_model="ollama_chat/${model}"

  ( cd "$ws" \
    && git init -q 2>/dev/null \
    && "$HOME/.local/bin/aider" \
        --model "$aider_model" \
        --no-auto-commits \
        --no-show-model-warnings \
        --no-stream \
        --no-pretty \
        --no-analytics \
        --yes-always \
        --message-file "$prompt_file" \
        "$@" )
  local rc=$?

  # Aider writes .aider.chat.history.md in cwd; copy for inspection
  [[ -f "$ws/.aider.chat.history.md" ]] && cp "$ws/.aider.chat.history.md" "$run_dir/aider.chat.history.md"
  [[ -f "$ws/.aider.input.history" ]]   && cp "$ws/.aider.input.history"   "$run_dir/aider.input.history"

  # Token totals: aider prints "Tokens: X sent, Y received" lines we can scrape from stdout.log
  if [[ -f "$run_dir/stdout.log" ]]; then
    python3 - "$run_dir/stdout.log" "$run_dir" <<'PY'
import re, sys
ti=to=0
text=open(sys.argv[1]).read()
# Aider lines look like: "Tokens: 1.2k sent, 234 received."
for m in re.finditer(r'Tokens:\s*([\d.]+)([kK]?)\s*sent,\s*([\d.]+)([kK]?)\s*received', text):
    a=float(m.group(1))*(1000 if m.group(2).lower()=='k' else 1)
    b=float(m.group(3))*(1000 if m.group(4).lower()=='k' else 1)
    ti+=int(a); to+=int(b)
# Tool calls: aider shows file edits. Count them as a proxy.
tc=len(re.findall(r'^\s*[A-Za-z0-9_./-]+\s*$', text, re.M))  # rough; replace later
open(sys.argv[2]+'/tokens_in','w').write(str(ti))
open(sys.argv[2]+'/tokens_out','w').write(str(to))
open(sys.argv[2]+'/tool_calls','w').write(str(0))
PY
  fi
  return $rc
}
