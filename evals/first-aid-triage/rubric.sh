#!/usr/bin/env bash
# first-aid-triage - START protocol on 5 patients.
# Expected: P1=GREEN, P2=BLACK, P3=RED, P4=GREEN, P5=RED
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

# Helper: extract the color called out for a numbered patient
get_color() {
  local n="$1"
  # Look for line beginning "Patient N" up to first GREEN/YELLOW/RED/BLACK token
  grep -iE "^[[:space:]]*\*?\*?patient[[:space:]]*${n}\b" "$A" 2>/dev/null \
    | head -1 \
    | grep -oiE 'GREEN|YELLOW|RED|BLACK' \
    | head -1 \
    | tr '[:lower:]' '[:upper:]'
}

if [[ -f "$A" ]]; then
  declare -A expected=( [1]=GREEN [2]=BLACK [3]=RED [4]=GREEN [5]=RED )
  for n in 1 2 3 4 5; do
    got=$(get_color "$n")
    if [[ "$got" == "${expected[$n]}" ]]; then
      add "p${n}_correct_(${expected[$n]})" 1 15 "got=$got"
    else
      add "p${n}_correct_(${expected[$n]})" 0 15 "got=${got:-none}"
    fi
  done

  # Justification quality - looks for keywords linking to START rules
  if grep -qiE 'walk|walking|ambulat' "$A"; then
    add "uses_walk_rule" 1 5
  else
    add "uses_walk_rule" 0 5
  fi
  if grep -qiE 'respiratory.*(rate|>30|30/min|36/min)|breathing|airway' "$A"; then
    add "uses_breathing_rate_rule" 1 5
  else
    add "uses_breathing_rate_rule" 0 5
  fi
  if grep -qiE 'pulse|capillary|perfusion' "$A"; then
    add "uses_perfusion_rule" 1 5
  else
    add "uses_perfusion_rule" 0 5
  fi
  if grep -qiE 'command|mental|consciou|respond' "$A"; then
    add "uses_mental_status_rule" 1 5
  else
    add "uses_mental_status_rule" 0 5
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
