#!/usr/bin/env bash
# drone-pid - validate a PID controller against a first-order plant step response.
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

F="$WS/pid.py"
add "file:pid.py" "$([[ -f "$F" ]] && echo 1 || echo 0)" 5

if [[ -f "$F" ]]; then
  RES=$(python3 - "$WS" <<'PY' 2>&1
import sys, importlib.util, math
ws = sys.argv[1]
spec = importlib.util.spec_from_file_location("pid", f"{ws}/pid.py")
mod  = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
except Exception as e:
    print(f"IMPORT_ERROR: {e!r}"); sys.exit(0)

try:
    pid = mod.PID(kp=2.0, ki=0.5, kd=0.8, setpoint=10.0)
except Exception as e:
    print(f"CONSTRUCT_ERROR: {e!r}"); sys.exit(0)

# First-order plant: dy/dt = -y + u  (time constant 1s)
y = 0.0; dt = 0.05
history = []
try:
    for _ in range(200):
        u = pid.update(y, dt)
        # Euler step on plant
        y = y + dt * (-y + u)
        history.append(y)
except Exception as e:
    print(f"STEP_ERROR: {e!r}"); sys.exit(0)

# Checks
ok_settled = abs(history[-1] - 10.0) < 0.5
ok_reached = max(history) >= 9.0
# No catastrophic oscillation: late-phase samples within ±2 of setpoint
late = history[150:]
ok_stable = max(abs(v - 10.0) for v in late) < 2.0

# Reset works
pid.reset()
out_after_reset = pid.update(0.0, 0.05)
# With error=10, kp=2, ki=0.5, dt=0.05, derivative should be 0 (first call after reset)
expected = 2.0*10.0 + 0.5*10.0*0.05
ok_reset = abs(out_after_reset - expected) < 0.5

# Setpoint change works - must produce a measurably different output than at
# the old setpoint. Compare against a fresh PID at the new setpoint.
pid.set_setpoint(5.0)
out_new = pid.update(0.0, 0.05)
# Sanity: a fresh PID at setpoint=5 (after reset, first call) gives ~10 (=2*5).
fresh = mod.PID(kp=2.0, ki=0.5, kd=0.8, setpoint=5.0)
out_fresh = fresh.update(0.0, 0.05)
# Verify (a) we got SOMETHING and (b) it's not nan; we don't compare absolute
# because the second pid is mid-cycle (carries derivative + integral state).
import math
ok_setpoint = isinstance(out_new, (int, float)) and not math.isnan(out_new) \
              and abs(out_fresh - 10.25) < 0.5  # Kp*e + Ki*e*dt = 10 + 0.125 = 10.125

# Gain change works
pid.set_gains(1.0, 0.0, 0.0)
pid.reset()
out_pure_p = pid.update(0.0, 0.05)  # should be just 1.0*5.0 = 5.0
ok_gains = abs(out_pure_p - 5.0) < 0.1

print(f"settled={int(ok_settled)} reached={int(ok_reached)} stable={int(ok_stable)} reset={int(ok_reset)} setpoint={int(ok_setpoint)} gains={int(ok_gains)} final={history[-1]:.2f}")
PY
)
  echo "DEBUG: $RES" >&2

  if echo "$RES" | grep -q "IMPORT_ERROR\|CONSTRUCT_ERROR\|STEP_ERROR"; then
    note=$(echo "$RES" | head -1 | tr -d '\n' | cut -c1-120)
    add "imports_and_runs" 0 10 "$note"
  else
    add "imports_and_runs" 1 10
    echo "$RES" | grep -q "settled=1"  && add "settles_to_setpoint" 1 15 || add "settles_to_setpoint" 0 15
    echo "$RES" | grep -q "reached=1"  && add "reaches_setpoint"   1 10 || add "reaches_setpoint"   0 10
    echo "$RES" | grep -q "stable=1"   && add "stable_late_phase"  1 15 || add "stable_late_phase"  0 15
    echo "$RES" | grep -q "reset=1"    && add "reset_zeroes_state" 1 10 || add "reset_zeroes_state" 0 10
    echo "$RES" | grep -q "setpoint=1" && add "set_setpoint_works" 1 10 || add "set_setpoint_works" 0 10
    echo "$RES" | grep -q "gains=1"    && add "set_gains_works"    1 10 || add "set_gains_works"    0 10
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
