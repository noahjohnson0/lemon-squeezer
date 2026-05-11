#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

F="$WS/ik.py"
add "file:ik.py" "$([[ -f "$F" ]] && echo 1 || echo 0)" 5

if [[ -f "$F" ]]; then
  RES=$(python3 - "$WS" <<'PY' 2>&1
import sys, importlib.util, math
ws = sys.argv[1]
spec = importlib.util.spec_from_file_location("ik", f"{ws}/ik.py")
mod  = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
except Exception as e:
    print(f"IMPORT_ERROR: {repr(e)[:120]}"); sys.exit(0)

# 5 reachable targets (within 0 < r < 2)
targets = [(1.0, 0.5), (0.7, 0.7), (1.5, 0.3), (0.2, 1.4), (-0.5, 0.8)]
fk_round_trip = 0
for (x, y) in targets:
    try:
        t1, t2 = mod.inverse_kinematics(x, y, elbow="up")
        xr, yr = mod.forward_kinematics(t1, t2)
        if abs(xr - x) < 1e-3 and abs(yr - y) < 1e-3:
            fk_round_trip += 1
    except Exception:
        pass

# Unreachable target should raise
unreach_ok = 0
try:
    mod.inverse_kinematics(3.0, 0.0)
except ValueError:
    unreach_ok = 1
except Exception:
    unreach_ok = 0

# Elbow up vs down for (1.0, 0.5) should give different solutions, both valid
elbow_distinct = 0
try:
    a = mod.inverse_kinematics(1.0, 0.5, elbow="up")
    b = mod.inverse_kinematics(1.0, 0.5, elbow="down")
    if abs(a[1] - b[1]) > 1e-2:
        xu, yu = mod.forward_kinematics(*a)
        xd, yd = mod.forward_kinematics(*b)
        if (abs(xu-1.0)<1e-2 and abs(yu-0.5)<1e-2 and abs(xd-1.0)<1e-2 and abs(yd-0.5)<1e-2):
            elbow_distinct = 1
except Exception:
    pass

print(f"roundtrip={fk_round_trip}/5 unreach={unreach_ok} elbow={elbow_distinct}")
PY
)
  echo "DEBUG: $RES" >&2

  if echo "$RES" | grep -q "IMPORT_ERROR"; then
    note=$(echo "$RES" | head -1 | tr -d '\n' | cut -c1-120)
    add "imports" 0 10 "$note"
  else
    add "imports" 1 10
    rt=$(echo "$RES" | grep -oE 'roundtrip=[0-9]+' | cut -d= -f2)
    [[ "${rt:-0}" -ge 5 ]] && add "fk_ik_roundtrip_5/5" 1 40 || \
      ( [[ "${rt:-0}" -ge 3 ]] && add "fk_ik_roundtrip_5/5" 1 25 "got $rt/5" || add "fk_ik_roundtrip_5/5" 0 40 "got $rt/5" )

    echo "$RES" | grep -q "unreach=1" && add "raises_on_unreachable" 1 25 || add "raises_on_unreachable" 0 25
    echo "$RES" | grep -q "elbow=1"   && add "elbow_up_vs_down"      1 20 || add "elbow_up_vs_down"      0 20
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
