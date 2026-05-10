#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/circuit.py"
add "file:circuit.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys
try: from circuit import solve
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)
def near(a, b, tol=1e-3): return abs(a - b) < tol

# Voltage divider: V=10, R1=R2=1k → mid=5V
nl1 = "V1 vp gnd 10\nR1 vp n1 1000\nR2 n1 gnd 1000\n"
try:
    r = solve(nl1)
    print("vdiv_vp", 1 if near(r.get("vp",0), 10) else 0, r.get("vp"))
    print("vdiv_mid", 1 if near(r.get("n1",0), 5) else 0, r.get("n1"))
except Exception as e:
    print("vdiv_vp", 0, repr(e)); print("vdiv_mid", 0, repr(e))

# Three-resistor network — a node connects to gnd through 4 ohm and 5 ohm in parallel,
# fed from vp through 1 ohm. R_par = 4*5/9 = 20/9. V at node = 10 * (20/9)/(1+20/9) = 200/29 ≈ 6.8966
nl2 = "V1 vp gnd 10\nR1 vp a 1\nR2 a gnd 4\nR3 a gnd 5\n"
try:
    r = solve(nl2)
    print("threeR", 1 if near(r.get("a",0), 6.8966, 0.01) else 0, r.get("a"))
except Exception as e: print("threeR", 0, repr(e))

# Current source: 1 mA into 1k → 1V across
nl3 = "I1 gnd n1 0.001\nR1 n1 gnd 1000\n"
try:
    r = solve(nl3)
    print("isource", 1 if near(r.get("n1",0), 1.0) else 0, r.get("n1"))
except Exception as e: print("isource", 0, repr(e))

# Wheatstone (balanced): V=10, two equal-ratio dividers → both midpoints = 5V
nl4 = "V1 vp gnd 10\nR1 vp a 100\nR2 vp b 200\nR3 a gnd 100\nR4 b gnd 200\n"
try:
    r = solve(nl4)
    print("wheat_a", 1 if near(r.get("a",0), 5) else 0, r.get("a"))
    print("wheat_b", 1 if near(r.get("b",0), 5) else 0, r.get("b"))
except Exception as e:
    print("wheat_a", 0, repr(e)); print("wheat_b", 0, repr(e))

# Truly floating subnetwork: nodes b, c only connect to each other, with no path to gnd
nl5 = "V1 vp gnd 10\nR1 vp a 100\nR2 a gnd 200\nR3 b c 50\n"
try:
    solve(nl5); print("floating_raises", 0, "no raise — must reject singular system")
except ValueError: print("floating_raises", 1)
except Exception as e: print("floating_raises", 0, repr(e))
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    add "$name" "$pass" 11 "$note"
  done < <(echo "$RES")
else
  for n in compiles vdiv_mid; do add "$n" 0 5; done
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
