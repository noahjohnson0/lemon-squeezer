#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/orders.py"
add "file:orders.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 10 || add "compiles" 0 10

  # Defines customer_total
  grep -qE '^def customer_total\(' "$T" && add "defines:customer_total" 1 15 || add "defines:customer_total" 0 15

  # No more per-customer named totals (alice_total, bob_total, etc.)
  if grep -qE '\b(alice_total|bob_total|carol_total)\b' "$T"; then
    add "removes:hardcoded_per_customer" 0 10 "still has per-customer named totals"
  else
    add "removes:hardcoded_per_customer" 1 10
  fi

  # Iterates with the new function
  grep -qE 'customer_total\(' "$T" && add "uses:customer_total" 1 10 || add "uses:customer_total" 0 10

  # Run it and check exact output
  EXPECTED=$'alice paid 8.5\nbob paid 21.5\ncarol paid 3.0\ngrand total 33.0'
  OUT="$(cd "$WS" && gtimeout 5 python3 orders.py 2>&1)"
  if [[ "$OUT" == "$EXPECTED" ]]; then
    add "output:identical" 1 25
  else
    add "output:identical" 0 25 "got: $(echo "$OUT" | head -c 200 | tr $'\n' '|')"
  fi
else
  for n in compiles defines:customer_total removes:hardcoded_per_customer uses:customer_total output:identical; do
    add "$n" 0 5
  done
fi

# emit
total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in "${checks[@]}"; do
    IFS=$'\t' read -r name pass weight note <<<"$c"
    total=$((total+weight))
    [[ "$pass" == "1" ]] && gained=$((gained+weight))
    [[ $first -eq 0 ]] && printf ',\n'
    printf '    {"name":"%s","pass":%s,"weight":%s,"note":"%s"}' "$name" "$pass" "$weight" "$note"
    first=0
  done
  printf '\n  ],\n'
  pct=0
  [[ $total -gt 0 ]] && pct=$(( (gained * 100) / total ))
  printf '  "gained": %s,\n  "total": %s,\n  "score_pct": %s\n}\n' "$gained" "$total" "$pct"
}
