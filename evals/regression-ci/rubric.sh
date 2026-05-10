#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/stats.py"
add "file:stats.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys
try: from stats import linreg, mean_ci95
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)
def near(a, b, tol=1e-3):
    try: return abs(float(a)-float(b)) < tol
    except: return False
# linreg cases
LR = [
    ([1,2,3,4,5], [2,4,5,4,5], (0.6, 2.2, 0.6)),
    ([0,1,2,3], [1,3,5,7], (2.0, 1.0, 1.0)),
    ([1,2,3], [3,2,1], (-1.0, 4.0, 1.0)),
]
for i,(x,y,(s,b,r2)) in enumerate(LR,1):
    try:
        gs, gb, gr2 = linreg(x, y)
        ok = near(gs,s) and near(gb,b) and near(gr2,r2)
        print(f"lr{i}", 1 if ok else 0, f"got=({gs:.3f},{gb:.3f},{gr2:.3f}) want=({s},{b},{r2})")
    except Exception as e:
        print(f"lr{i}", 0, "ERR", repr(e))
# mean_ci95 cases
CI = [
    ([5.1,4.9,5.0,5.2,4.8,5.1,5.0,4.9,5.0,5.0], 5.0, (4.917, 5.083)),
    ([10,12,9,11,13], 11.0, (9.037, 12.963)),
]
for i,(d,m,(lo,hi)) in enumerate(CI,1):
    try:
        gm, glo, ghi = mean_ci95(d)
        ok = near(gm,m,1e-2) and near(glo,lo,5e-2) and near(ghi,hi,5e-2)
        print(f"ci{i}", 1 if ok else 0, f"got=({gm:.3f},{glo:.3f},{ghi:.3f}) want=({m},{lo:.3f},{hi:.3f})")
    except Exception as e:
        print(f"ci{i}", 0, "ERR", repr(e))
# n=1 must raise
try:
    mean_ci95([42.0]); print("ci_n1_raises", 0, "no raise")
except ValueError: print("ci_n1_raises", 1)
except Exception as e: print("ci_n1_raises", 0, repr(e))
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3- | tr -d "\\\\")
    [[ "$name" == "IMPORT_ERR" ]] && continue
    case "$name" in lr*) w=12;; ci*) w=12;; *) w=8;; esac
    add "$name" "$pass" "$w" "$note"
  done < <(echo "$RES")
else
  for n in compiles lr1 ci1; do add "$n" 0 5; done
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
