#!/usr/bin/env bash
# pi harness: runs pi non-interactively, then extracts session for token/tool counts.
harness_run() {
  local ws="$1" prompt_file="$2" model="$3" run_dir="$4"; shift 4
  local prompt; prompt="$(cat "$prompt_file")"

  ( cd "$ws" && pi --provider ollama --model "$model" --thinking off "$@" -p "$prompt" )
  local rc=$?

  # Locate pi session dir for this workspace
  local session_key
  session_key="--$(echo "$ws" | sed 's|^/||; s|/|-|g')--"
  local session_path="$HOME/.pi/agent/sessions/$session_key"
  if [[ -d "$session_path" ]]; then
    local latest
    latest="$(ls -1t "$session_path"/*.jsonl 2>/dev/null | head -1 || true)"
    [[ -n "$latest" ]] && cp "$latest" "$run_dir/session.jsonl"
  fi

  if [[ -f "$run_dir/session.jsonl" ]]; then
    python3 - "$run_dir/session.jsonl" "$run_dir" <<'PY'
import json, sys
ti=to=tc=0
for line in open(sys.argv[1]):
    try: d=json.loads(line)
    except: continue
    msg=d.get('message',{})
    u=msg.get('usage') or d.get('usage') or {}
    ti+=u.get('input',0) or 0
    to+=u.get('output',0) or 0
    # Pi v3 schema: assistant message content[] has {type:"toolCall"} entries
    if isinstance(msg.get('content'), list):
        for c in msg['content']:
            if isinstance(c, dict) and c.get('type') in ('toolCall','tool_use'):
                tc += 1
open(sys.argv[2]+'/tokens_in','w').write(str(ti))
open(sys.argv[2]+'/tokens_out','w').write(str(to))
open(sys.argv[2]+'/tool_calls','w').write(str(tc))
PY
  fi
  return $rc
}
