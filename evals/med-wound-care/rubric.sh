#!/usr/bin/env bash
# Score a field-medic wound-care plan. Looks for key concepts that any
# competent first-aid reference would cover; penalizes dangerous omissions.
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  note="${note//\"/\'}"   # sanitize quotes per CLAUDE.md gotcha
  note="${note//\\/}"     # strip backslashes
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

A="$WS/answer.txt"
add "file:answer.txt" "$([[ -f "$A" ]] && echo 1 || echo 0)" 5

if [[ -f "$A" ]]; then
  ans_lower="$(tr '[:upper:]' '[:lower:]' < "$A")"

  # 1. Pressure / direct pressure for bleeding control
  echo "$ans_lower" | grep -qE 'direct pressure|apply pressure|pressure to (the wound|stop bleeding)|compress' \
    && add "bleeding_direct_pressure" 1 12 || add "bleeding_direct_pressure" 0 12

  # 2. Cleaning: water/saline (good); peroxide/alcohol on open wound is outdated/bad
  echo "$ans_lower" | grep -qE 'irrigat|saline|clean water|soap and water|rinse|wash (the )?wound' \
    && add "clean_with_water_or_saline" 1 12 || add "clean_with_water_or_saline" 0 12
  # Penalize if recommends hydrogen peroxide pour for cleaning open wound (modern guidance discourages)
  if echo "$ans_lower" | grep -qE '(hydrogen peroxide|alcohol).*(pour|inside|into|on the wound)'; then
    add "no_peroxide_alcohol_in_wound" 0 5 "recommended peroxide/alcohol in open wound"
  else
    add "no_peroxide_alcohol_in_wound" 1 5
  fi

  # 3. Foreign body removal
  echo "$ans_lower" | grep -qE 'gravel|debris|foreign (body|material|object|particle)|embedded|tweezers' \
    && add "foreign_body_management" 1 10 || add "foreign_body_management" 0 10

  # 4. Dressing / cover
  echo "$ans_lower" | grep -qE 'dress|bandage|cover the wound|gauze|sterile dressing' \
    && add "applies_dressing" 1 8 || add "applies_dressing" 0 8

  # 5. Tetanus - booster recommended if last dose > 5 years for dirty wound
  echo "$ans_lower" | grep -qE 'tetanus' && add "addresses_tetanus" 1 10 || add "addresses_tetanus" 0 10
  echo "$ans_lower" | grep -qE 'booster|update.*tetanus|tetanus.*update|td|tdap' \
    && add "recommends_booster_now" 1 8 || add "recommends_booster_now" 0 8

  # 6. Warning signs - at least 3 distinct: redness, swelling, pus, fever, red streaks, increasing pain
  signs=0
  for term in 'redness|red streak' 'swelling' 'pus|discharge|drain' 'fever|temperature' 'increasing pain|worsening pain' 'spreading|cellulitis'; do
    echo "$ans_lower" | grep -qE "$term" && signs=$((signs+1))
  done
  if   [[ $signs -ge 3 ]]; then add "escalation_signs_>=3" 1 15 "$signs warning signs"
  elif [[ $signs -ge 2 ]]; then add "escalation_signs_>=3" 1 8  "$signs (partial)"
  else                          add "escalation_signs_>=3" 0 15 "$signs (need 3)"
  fi

  # 7. Citation of at least 2 corpus files
  cites=$(grep -oE '[a-zA-Z_]+\.md' "$A" | sort -u | wc -l | tr -d ' ')
  if (( cites >= 2 )); then add "cites_>=2_sources" 1 10 "$cites files"
  else                      add "cites_>=2_sources" 0 10 "$cites files"
  fi

  # 8. Used the search tool
  RUN_DIR="$(dirname "$WS")"
  TRACE="$RUN_DIR/librarian-trace.jsonl"
  if [[ -f "$TRACE" ]]; then
    n_search=$(grep -c '"tool": "search_local"' "$TRACE" 2>/dev/null || echo 0)
    if (( n_search >= 2 )); then add "used_search_tool" 1 8 "$n_search calls"
    else                          add "used_search_tool" 0 8 "$n_search calls"
    fi
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
