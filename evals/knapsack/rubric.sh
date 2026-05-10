#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/knapsack.py"
add "file:knapsack.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys
try: from knapsack import solve
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)
def check(items, cap, expected):
    v, idxs = solve(items, cap)
    # validate idxs are valid + weight + value match v
    if not all(0 <= i < len(items) for i in idxs): return False, "bad idxs"
    if len(set(idxs)) != len(idxs): return False, "duplicate idxs"
    w = sum(items[i][0] for i in idxs)
    val = sum(items[i][1] for i in idxs)
    if w > cap: return False, f"weight {w} > cap"
    if val != v: return False, f"value mismatch {val} != {v}"
    if v != expected: return False, f"value {v} != expected {expected}"
    return True, "ok"

cases = [
    # (items, capacity, expected_max_value)
    ([(2,3),(3,4),(4,5),(5,6)], 5, 7),       # take items 0+1: w=5, v=7
    ([(1,1),(2,2),(3,3),(4,4)], 5, 5),       # multiple options
    ([(10,60),(20,100),(30,120)], 50, 220),  # classic textbook
    ([(1,1)], 0, 0),                         # zero capacity
    ([], 10, 0),                             # empty
    ([(5,10)], 4, 0),                        # one too-heavy
    ([(5,10),(3,5),(2,3)], 5, 10),           # take just 0
]
for i,(items,cap,exp) in enumerate(cases,1):
    try:
        ok, msg = check(items, cap, exp)
        print(f"k{i}", 1 if ok else 0, msg)
    except Exception as e:
        print(f"k{i}", 0, "ERR", repr(e))
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    add "$name" "$pass" 9 "$note"
  done < <(echo "$RES")
else
  for n in compiles k1 k2 k3; do add "$n" 0 5; done
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
