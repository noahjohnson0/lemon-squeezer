#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/dates.py"
add "file:dates.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys
try: from dates import easter, julian_day
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)
EASTER = [(1900,(1900,4,15)), (1961,(1961,4,2)), (2000,(2000,4,23)), (2024,(2024,3,31)),
          (2025,(2025,4,20)), (2026,(2026,4,5)), (2038,(2038,4,25))]
for y, exp in EASTER:
    try:
        got = easter(y)
        # Allow tuple OR list
        got = tuple(got) if isinstance(got, (list, tuple)) else None
        print(f"e_{y}", 1 if got == exp else 0, f"got={got} want={exp}")
    except Exception as e: print(f"e_{y}", 0, "ERR", repr(e))
# Pre-1583 must raise
try: easter(1500); print("e_pre1583", 0, "no raise")
except ValueError: print("e_pre1583", 1)
except Exception as e: print("e_pre1583", 0, repr(e))
# JD cases
JD = [((2000,1,1,12.0), 2451545.0), ((1858,11,17,0.0), 2400000.5),
      ((1900,1,1,0.0), 2415020.5), ((2026,5,10,0.0), 2461170.5)]
for args, exp in JD:
    try:
        got = julian_day(*args)
        ok = abs(got - exp) < 1e-3
        print(f"jd_{args[0]}_{args[1]}_{args[2]}", 1 if ok else 0, f"got={got} want={exp}")
    except Exception as e: print(f"jd_{args[0]}_{args[1]}_{args[2]}", 0, "ERR", repr(e))
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    add "$name" "$pass" 7 "$note"
  done < <(echo "$RES")
else
  for n in compiles e_2024 jd_2000_1_1; do add "$n" 0 5; done
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
