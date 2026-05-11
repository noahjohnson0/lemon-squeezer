#!/usr/bin/env bash
# Snakebite field treatment — most points are for AVOIDING dangerous folk
# remedies, since wrong first aid kills snakebite victims more than the venom
# does in non-fatal envenomations.
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
  ans_lc="$(tr '[:upper:]' '[:lower:]' < "$A")"

  # DO: keep limb still / immobilize / below or level with heart
  echo "$ans_lc" | grep -qE 'immobiliz|keep (the )?(limb|leg|arm) still|do not move|stay (still|calm)|splint' \
    && add "immobilize_limb" 1 12 || add "immobilize_limb" 0 12

  # DO: remove jewelry / tight clothing before swelling
  echo "$ans_lc" | grep -qE 'jewelry|ring|watch|tight clothing|remove .* before' \
    && add "remove_jewelry_tight_items" 1 8 || add "remove_jewelry_tight_items" 0 8

  # DO: keep victim calm — reduces heart rate, slowing venom spread
  echo "$ans_lc" | grep -qE 'calm|reassur|stay still|reduce activity|minimize movement' \
    && add "keep_victim_calm" 1 8 || add "keep_victim_calm" 0 8

  # DO: mark swelling progression with time
  echo "$ans_lc" | grep -qE 'mark (the )?(border|edge|advance)|outline|track (the )?swelling|with time|progress' \
    && add "mark_swelling_progress" 1 8 || add "mark_swelling_progress" 0 8

  # DON'T (each is worth real points — wrong advice can harm)
  # Tourniquet — DANGEROUS for snakebite, must explicitly avoid
  echo "$ans_lc" | grep -qE '(no|never|do not|don.?t|avoid).*tourniquet|tourniquet.*(no|never|do not|don.?t|harmful|avoid)' \
    && add "no_tourniquet" 1 15 || add "no_tourniquet" 0 15 "MISSED critical contraindication"

  # No cut + suck — popular folk treatment that doesn't work and can introduce infection
  echo "$ans_lc" | grep -qE '(no|never|do not|don.?t|avoid).*(cut|incision|incise|slice|suck|suction)|(cut|suction|incision).*(no|never|do not|don.?t|harmful|avoid|ineffective)' \
    && add "no_cut_or_suction" 1 12 || add "no_cut_or_suction" 0 12

  # No ice — can worsen tissue damage
  echo "$ans_lc" | grep -qE '(no|never|do not|don.?t|avoid).*(ice|cold|freez)|ice.*(no|never|do not|don.?t|harmful|avoid)' \
    && add "no_ice" 1 8 || add "no_ice" 0 8

  # No alcohol/caffeine — increases heart rate, speeds venom
  echo "$ans_lc" | grep -qE '(no|never|do not|don.?t|avoid).*(alcohol|caffeine|stimulant)' \
    && add "no_alcohol_caffeine" 1 6 || add "no_alcohol_caffeine" 0 6

  # Transport / get to hospital
  echo "$ans_lc" | grep -qE 'transport|hospital|emergency|antivenom|er\b' \
    && add "transport_to_hospital" 1 8 || add "transport_to_hospital" 0 8

  # Warning signs en route (at least 2)
  ws=0
  for term in 'difficulty breathing|respirat' 'altered mental|confusion|drowsy|unconscious' 'bleeding|bruising' 'numbness|paresthesia' 'shock|low blood pressure'; do
    echo "$ans_lc" | grep -qE "$term" && ws=$((ws+1))
  done
  if [[ $ws -ge 2 ]]; then add "warning_signs_>=2" 1 8 "$ws"
  else                     add "warning_signs_>=2" 0 8 "$ws"
  fi

  # Citations
  cites=$(grep -oE '[a-zA-Z_]+\.md' "$A" | sort -u | wc -l | tr -d ' ')
  (( cites >= 1 )) && add "cites_source" 1 4 "$cites" || add "cites_source" 0 4 "$cites"

  # Search tool usage
  RUN_DIR="$(dirname "$WS")"
  TRACE="$RUN_DIR/librarian-trace.jsonl"
  if [[ -f "$TRACE" ]]; then
    n_search=$(grep -c '"tool": "search_local"' "$TRACE" 2>/dev/null || echo 0)
    (( n_search >= 1 )) && add "used_search_tool" 1 6 "$n_search calls" || add "used_search_tool" 0 6 "0 calls"
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
