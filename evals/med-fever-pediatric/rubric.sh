#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  note="${note//\"/\'}"; note="${note//\\/}"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

A="$WS/answer.txt"
add "file:answer.txt" "$([[ -f "$A" ]] && echo 1 || echo 0)" 5

if [[ -f "$A" ]]; then
  ans="$(cat "$A")"
  ans_lc="$(tr '[:upper:]' '[:lower:]' < "$A")"

  # 1. Fever threshold - 100.4°F or 38°C is the canonical pediatric fever cutoff
  echo "$ans" | grep -qE '100\.4|38(\.0)? ?°?C' && add "fever_threshold" 1 8 || add "fever_threshold" 0 8

  # 2. Paracetamol / acetaminophen mentioned
  echo "$ans_lc" | grep -qE 'paracetamol|acetaminophen|tylenol' \
    && add "mentions_paracetamol" 1 5 || add "mentions_paracetamol" 0 5

  # 2a. Paracetamol dose 10-15 mg/kg
  echo "$ans" | grep -qE '1[0-5] ?mg\s*/\s*kg|10[ -]15 ?mg\s*/\s*kg|15 ?mg\s*/\s*kg' \
    && add "paracetamol_dose_per_kg" 1 12 || add "paracetamol_dose_per_kg" 0 12

  # 3. Ibuprofen mentioned
  echo "$ans_lc" | grep -qE 'ibuprofen|advil|motrin' \
    && add "mentions_ibuprofen" 1 5 || add "mentions_ibuprofen" 0 5

  # 3a. Ibuprofen dose 5-10 mg/kg (q6-8h)
  echo "$ans" | grep -qE '[5-9] ?mg\s*/\s*kg|10 ?mg\s*/\s*kg|5[ -]10 ?mg\s*/\s*kg' \
    && add "ibuprofen_dose_per_kg" 1 12 || add "ibuprofen_dose_per_kg" 0 12

  # 3b. Mentions some interval (q4-6h, q6-8h)
  echo "$ans_lc" | grep -qE 'every (4|6|8) ?hours?|q ?[468] ?h|4-6 ?h|6-8 ?h' \
    && add "dosing_interval" 1 8 || add "dosing_interval" 0 8

  # 4. Mentions a max daily dose
  echo "$ans_lc" | grep -qE 'max(imum)? (daily|24[- ]hour|per day)|do not exceed|no more than .* per day|max.*g/day|max.*mg/day' \
    && add "states_max_daily_dose" 1 10 || add "states_max_daily_dose" 0 10

  # 5. Red flags - at least 3 of: lethargy, stiff neck, rash, breathing, dehydration, fever >40C / 104F, seizure
  rf=0
  for term in 'lethargy|lethargic|unresponsive|hard to wake' 'stiff neck|nuchal' 'rash|petechia|purpura' 'breathing|respirat' 'dehydrat|not drinking|no wet diap' '104|40 ?°c|40c' 'seizure|convulsion'; do
    echo "$ans_lc" | grep -qE "$term" && rf=$((rf+1))
  done
  if   [[ $rf -ge 3 ]]; then add "red_flags_>=3" 1 15 "$rf flags"
  elif [[ $rf -ge 2 ]]; then add "red_flags_>=3" 1 8  "$rf"
  else                       add "red_flags_>=3" 0 15 "$rf"
  fi

  # 6. Hydration advice
  echo "$ans_lc" | grep -qE 'hydrat|fluid|drink|water|electrolyte|oral rehydr' \
    && add "hydration_advice" 1 5 || add "hydration_advice" 0 5

  # 7. Citations
  cites=$(grep -oE '[a-zA-Z_]+\.md' "$A" | sort -u | wc -l | tr -d ' ')
  if (( cites >= 2 )); then add "cites_>=2_sources" 1 7 "$cites"
  else                      add "cites_>=2_sources" 0 7 "$cites"
  fi

  # 8. Used search tool
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
