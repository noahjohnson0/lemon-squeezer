#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

F="$WS/pf.py"
add "file:pf.py" "$([[ -f "$F" ]] && echo 1 || echo 0)" 5

if [[ -f "$F" ]]; then
  RES=$(python3 - "$WS" <<'PY' 2>&1
import sys, importlib.util, random
random.seed(42)
try:
    import numpy as np
    np.random.seed(42)
except ImportError:
    np = None

ws = sys.argv[1]
spec = importlib.util.spec_from_file_location("pf", f"{ws}/pf.py")
mod  = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
except Exception as e:
    print(f"IMPORT_ERROR: {repr(e)[:200]}"); sys.exit(0)

try:
    pf = mod.ParticleFilter(n_particles=300, corridor_length=10.0)
except Exception as e:
    print(f"CONSTRUCT_ERROR: {repr(e)[:200]}"); sys.exit(0)

# Simulate ground truth + sensor + odometry
truth = 2.0
control = 0.2          # meters per step
mot_noise = 0.05
sens_noise = 0.3
errors = []
try:
    for step in range(30):
        # ground truth moves
        truth += control
        if truth >= 9.8: break
        # noisy observations
        obs = (10.0 - truth) + random.gauss(0, sens_noise)
        odo = control + random.gauss(0, mot_noise)
        pf.predict(odo, motion_noise_std=mot_noise)
        pf.update(obs, sensor_noise_std=sens_noise)
        est = pf.estimate()
        errors.append(abs(est - truth))
except Exception as e:
    print(f"STEP_ERROR: {repr(e)[:200]}"); sys.exit(0)

# Convergence: average error of last 10 steps under 0.7m
late_avg = sum(errors[-10:]) / max(1, len(errors[-10:]))
final_err = errors[-1] if errors else 999
n_steps = len(errors)

# Also verify estimate() returns a scalar
try:
    e = pf.estimate()
    is_scalar = isinstance(e, (int, float)) or (np is not None and isinstance(e, np.floating))
except Exception:
    is_scalar = False

print(f"steps={n_steps} late_avg={late_avg:.3f} final={final_err:.3f} scalar={int(is_scalar)}")
PY
)
  echo "DEBUG: $RES" >&2

  if echo "$RES" | grep -q "IMPORT_ERROR\|CONSTRUCT_ERROR\|STEP_ERROR"; then
    note=$(echo "$RES" | head -1 | tr -d '\n' | cut -c1-120)
    add "imports_and_runs" 0 15 "$note"
  else
    add "imports_and_runs" 1 15
    steps=$(echo "$RES" | grep -oE 'steps=[0-9]+' | cut -d= -f2)
    [[ "${steps:-0}" -ge 20 ]] && add "ran_to_convergence" 1 10 "ran $steps steps" || add "ran_to_convergence" 0 10 "only $steps steps"

    late=$(echo "$RES" | grep -oE 'late_avg=[0-9.]+' | cut -d= -f2)
    if python3 -c "import sys; v=float('$late'); sys.exit(0 if v<0.7 else 1)" 2>/dev/null; then
      add "converges_within_0.7m" 1 30 "late_avg=$late"
    else
      add "converges_within_0.7m" 0 30 "late_avg=$late"
    fi

    final=$(echo "$RES" | grep -oE 'final=[0-9.]+' | cut -d= -f2)
    if python3 -c "import sys; v=float('$final'); sys.exit(0 if v<1.0 else 1)" 2>/dev/null; then
      add "final_within_1m" 1 15 "final=$final"
    else
      add "final_within_1m" 0 15 "final=$final"
    fi

    echo "$RES" | grep -q "scalar=1" && add "estimate_returns_scalar" 1 10 || add "estimate_returns_scalar" 0 10
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
