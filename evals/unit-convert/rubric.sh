#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/convert.py"
add "file:convert.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  # Each test: input → expected stdout substring (lowercase compare on number) OR expected exit nonzero
  run_case() {
    local n="$1" inp="$2" expected="$3" want_err="${4:-0}"
    local out rc
    out=$(cd "$WS" && gtimeout 5 python3 convert.py "$inp" 2>/dev/null)
    rc=$?
    if [[ "$want_err" == "1" ]]; then
      [[ "$rc" -ne 0 ]] && add "$n" 1 7 "expected error, got exit $rc" || add "$n" 0 7 "expected error but got: $out"
    else
      # Compare just the number to 2 dp tolerance (handle floating point)
      local got_num want_num
      got_num=$(echo "$out" | awk '{print $1}')
      want_num=$(echo "$expected" | awk '{print $1}')
      if python3 -c "
import sys
try:
    g = float(sys.argv[1]); w = float(sys.argv[2])
    sys.exit(0 if abs(g - w) < 0.01 else 1)
except (ValueError, IndexError):
    sys.exit(1)
" "$got_num" "$want_num"; then
        add "$n" 1 7 "got=$out"
      else
        add "$n" 0 7 "got='$out' want='$expected'"
      fi
    fi
  }
  run_case "ft_in_to_cm"   "5 ft 7 in to cm"   "170.18 cm"
  run_case "mile_to_km"    "1 mile to km"      "1.6093 km"
  run_case "c_to_f"        "100 C to F"        "212.0 F"
  run_case "f_to_c"        "32 F to C"         "0.0 C"
  run_case "kg_to_lb"      "1 kg to lb"        "2.2046 lb"
  run_case "ft_in_to_m"    "5 ft 11 in to m"   "1.8034 m"
  run_case "gal_to_l"      "1 gal to L"        "3.7854 L"
  run_case "mph_to_kph"    "60 mph to kph"     "96.5606 kph"
  run_case "incompatible1" "5 kg to m"         "" 1
  run_case "incompatible2" "100 C to ft"       "" 1
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
