#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/kepler.py"
add "file:kepler.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  # RK4 marker
  if grep -qE 'k1|k_1' "$T" && grep -qE 'k2|k_2' "$T" && grep -qE 'k3|k_3' "$T" && grep -qE 'k4|k_4' "$T"; then
    add "uses_rk4" 1 8
  else
    add "uses_rk4" 0 8 "no k1..k4 in code"
  fi
  RES=$(cd "$WS" && gtimeout 30 python3 - <<'PY' 2>&1
import sys, math
try: from kepler import simulate, total_energy
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)
def near(a,b,tol): return abs(a-b) < tol
# Energy formula
E0 = total_energy(1, 0, 0, 1)
print("energy_formula", 1 if near(E0, -0.5, 1e-9) else 0, f"got={E0}")
# Half period
try:
    x,y,vx,vy = simulate(1, 0, 0, 1, math.pi, 1e-3)
    ok = near(x, -1, 0.05) and near(y, 0, 0.05)
    print("half_period", 1 if ok else 0, f"got=({x:.3f},{y:.3f})")
except Exception as e: print("half_period", 0, repr(e))
# Full period
try:
    x,y,vx,vy = simulate(1, 0, 0, 1, 2*math.pi, 1e-3)
    ok = near(x, 1, 0.05) and near(y, 0, 0.05)
    print("full_period", 1 if ok else 0, f"got=({x:.3f},{y:.3f})")
    # Energy drift
    E1 = total_energy(x, y, vx, vy)
    drift = abs(E1 - (-0.5))
    print("energy_drift", 1 if drift < 1e-3 else 0, f"drift={drift:.6f}")
except Exception as e:
    print("full_period", 0, repr(e)); print("energy_drift", 0, repr(e))
# Ellipse eccentricity 0.5: at r=0.5, v_perp = sqrt(GM*(2/r - 1/a)) with a=1 -> sqrt(2/0.5 - 1) = sqrt(3)
try:
    x,y,vx,vy = simulate(0.5, 0, 0, math.sqrt(3), math.pi, 1e-3)
    r = math.sqrt(x*x + y*y)
    # apoapsis distance for e=0.5, a=1 → r_apo = a(1+e) = 1.5
    print("ellipse_apo", 1 if near(r, 1.5, 0.05) else 0, f"r={r:.3f}")
except Exception as e: print("ellipse_apo", 0, repr(e))
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    case "$name" in
      energy_drift)  w=14;;
      full_period)   w=14;;
      half_period)   w=12;;
      ellipse_apo)   w=12;;
      energy_formula) w=8;;
      *) w=5;;
    esac
    add "$name" "$pass" "$w" "$note"
  done < <(echo "$RES")
else
  for n in compiles full_period; do add "$n" 0 5; done
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
