#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/kalman.py"
add "file:kalman.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  RES=$(cd "$WS" && gtimeout 15 python3 - <<'PY' 2>&1
import sys, random
try: from kalman import Kalman1D
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)
random.seed(42)

# Test 1: filter exists with right interface
try:
    k = Kalman1D(0.0, 0.0, 0.01, 0.5, 1.0)
    p, v = k.state()
    print("init",       1 if abs(p - 0.0) < 1e-9 and abs(v - 0.0) < 1e-9 else 0)
    cov = k.covariance()
    print("cov_2x2",    1 if len(cov) == 2 and len(cov[0]) == 2 else 0)
except Exception as e:
    print("init", 0, repr(e)); print("cov_2x2", 0, repr(e))

# Test 2: convergence - true velocity 1.0 m/s, noise ~N(0, 0.5)
try:
    k = Kalman1D(0.0, 0.0, 0.01, 0.5, 1.0)
    true_v = 1.0
    for step in range(1, 51):
        k.predict()
        z = step * true_v + random.gauss(0, 0.7)  # noisy measurement
        k.update(z)
    p, v = k.state()
    # After 50 steps with constant velocity, position should be ~50 and velocity ~1.0
    print("converge_pos", 1 if abs(p - 50.0) < 5.0 else 0, f"got_p={p:.3f}")
    print("converge_vel", 1 if abs(v - 1.0)  < 0.3 else 0, f"got_v={v:.3f}")
except Exception as e:
    print("converge_pos", 0, repr(e)); print("converge_vel", 0, repr(e))

# Test 3: no measurements → predict only - covariance should grow
try:
    k = Kalman1D(0.0, 1.0, 0.01, 0.5, 1.0)
    p0, v0 = k.state()
    cov0 = k.covariance()
    k.predict(); k.predict(); k.predict()
    p1, v1 = k.state()
    cov1 = k.covariance()
    grew = cov1[0][0] > cov0[0][0]
    advanced = abs(p1 - 3.0) < 1e-6  # 3 steps × velocity 1
    print("predict_advances", 1 if advanced else 0, f"p0={p0} p1={p1}")
    print("predict_grows_cov", 1 if grew else 0)
except Exception as e:
    print("predict_advances", 0, repr(e)); print("predict_grows_cov", 0, repr(e))
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
  for n in compiles converge_vel; do add "$n" 0 5; done
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
