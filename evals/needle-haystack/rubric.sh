#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

A="$WS/answer.txt"
add "file:answer.txt" "$([[ -f "$A" ]] && echo 1 || echo 0)" 5

if [[ -f "$A" ]]; then
  ans="$(cat "$A")"
  # Did the model find the access code?
  echo "$ans" | grep -q "RAINBOW-7942-OMEGA" && add "found_access_code" 1 60 || \
    add "found_access_code" 0 60 "expected RAINBOW-7942-OMEGA"
  # Did it find the coordinates? (distractor — should also have been mentioned)
  echo "$ans" | grep -q "47.6062" && add "found_coordinates" 1 10 || \
    add "found_coordinates" 0 10
  # Brevity: shorter is better for a needle-extraction task
  chars=$(wc -c < "$A" | tr -d ' ')
  if (( chars < 200 )); then
    add "concise_answer" 1 15 "$chars chars"
  elif (( chars < 1000 )); then
    add "concise_answer" 0 15 "$chars chars (verbose)"
  else
    add "concise_answer" 0 15 "$chars chars (very verbose)"
  fi
fi

total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in "${checks[@]}"; do
    IFS=$'\t' read -r name pass weight note <<<"$c"
    total=$((total+weight)); [[ "$pass" == "1" ]] && gained=$((gained+weight))
    [[ $first -eq 0 ]] && printf ',\n'
    printf '    {"name":"%s","pass":%s,"weight":%s,"note":"%s"}' "$name" "$pass" "$weight" "$note"
    first=0
  done
  printf '\n  ],\n'
  pct=0; [[ $total -gt 0 ]] && pct=$(( (gained * 100) / total ))
  printf '  "gained": %s,\n  "total": %s,\n  "score_pct": %s\n}\n' "$gained" "$total" "$pct"
}
