#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  # sanitize note: strip backslashes and double-quotes so the JSON stays valid
  note="${note//\\/ }"
  note="${note//\"/\'}"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

# weight table - one entry per declared check. The denominator is the SUM of
# these weights and MUST be constant regardless of how broken the submission is.
weight_for() { case "$1" in
  re_*)    echo 8;;
  beam_*)  echo 9;;
  rc_*)    echo 6;;
  vd_*)    echo 6;;
  imports) echo 8;;
  *)       echo 5;;
esac; }

# The full, fixed list of behavioral check names emitted by the python block.
# Used as a fallback so every check is scored even if python dies entirely.
BEHAVE_CHECKS="imports re_water_pipe re_air_wing re_unit beam_steel beam_unit rc_tau_1uF rc_tau_big vd_equal vd_1k_10k vd_zero_r2"

T="$WS/engineering.py"
add "file:engineering.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

# compiles check - always emitted (0 if file missing or does not compile)
if [[ -f "$T" ]] && python3 -m py_compile "$T" 2>/dev/null; then
  add "compiles" 1 5
else
  add "compiles" 0 5
fi

# Behavioral block. The python NEVER sys.exit()s and the chk() helper ALWAYS
# prints exactly one line per check, so the set of emitted check names is
# constant whether the import succeeds, fails, or any individual case raises.
if [[ -f "$T" ]]; then
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys

ok = True
try:
    from engineering import reynolds, beam_deflection_max, rc_time_constant, voltage_divider
except Exception as e:
    print("IMPORT_ERR", repr(e), file=sys.stderr)
    ok = False

def near(a, b, tol):
    try:
        return abs(float(a) - float(b)) / max(abs(float(b)), 1e-12) < tol
    except Exception:
        return False

def chk(name, fn):
    # ALWAYS prints a line. Import failure or any exception -> pass 0.
    if not ok:
        print(name, 0, "import_failed")
        return
    try:
        print(name, 1 if fn() else 0)
    except Exception as ex:
        print(name, 0, "exc", type(ex).__name__)

# explicit import gate so a non-importing file is penalized directly
print("imports", 1 if ok else 0)

# Reynolds - water at 20C: rho=998, mu=1.002e-3, water in 25mm pipe at 1 m/s
chk("re_water_pipe", lambda: near(reynolds(998, 1.0, 0.025, 1.002e-3), 24900, 0.01))
# Air over a wing: rho=1.225, mu=1.81e-5, v=50, L=2 -> ~6.77e6
chk("re_air_wing",   lambda: near(reynolds(1.225, 50, 2.0, 1.81e-5), 6767955, 0.01))
# Laminar threshold: rho=1000, mu=1e-3, v=0.001, L=0.001 -> Re=1
chk("re_unit",       lambda: near(reynolds(1000, 0.001, 0.001, 1e-3), 1.0, 0.001))

# Beam deflection - steel I-beam, P=10kN, L=4m, E=200e9, I=8.33e-6 -> ~0.008003
chk("beam_steel",    lambda: near(beam_deflection_max(10000, 4, 200e9, 8.33e-6), 0.008003, 0.01))
# Pure-formula check: P=L=E=I=1, expect 1/48
chk("beam_unit",     lambda: near(beam_deflection_max(1, 1, 1, 1), 1/48, 0.001))

# RC tau
chk("rc_tau_1uF",    lambda: near(rc_time_constant(1000, 1e-6), 0.001, 0.001))
chk("rc_tau_big",    lambda: near(rc_time_constant(1e6, 470e-6), 470, 0.001))

# Voltage divider - 9V across two equal Rs -> 4.5V midpoint
chk("vd_equal",      lambda: near(voltage_divider(9.0, 1000, 1000), 4.5, 0.001))
# 12V, R1=10k, R2=1k -> 12 * 1k/11k = 1.0909
chk("vd_1k_10k",     lambda: near(voltage_divider(12.0, 10000, 1000), 1.0909, 0.001))
# Edge: zero R2 -> zero out
chk("vd_zero_r2",    lambda: near(voltage_divider(5.0, 1000, 0), 0.0, 1e-9))
PY
)
  echo "$RES" >&2

  # Collect which behavioral checks python actually emitted.
  emitted=""
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    [[ "$name" == "IMPORT_ERR" ]] && continue
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    add "$name" "$pass" "$(weight_for "$name")" "$note"
    emitted="$emitted $name "
  done < <(echo "$RES")

  # Backstop: if python died before emitting some check (e.g. killed by the
  # timeout), score the missing ones as 0 so the denominator stays constant.
  for n in $BEHAVE_CHECKS; do
    [[ "$emitted" == *" $n "* ]] || add "$n" 0 "$(weight_for "$n")" "not_emitted"
  done

  # Static check - no third-party imports
  if grep -qE "^\s*import\s+(numpy|scipy|sympy)" "$T"; then
    add "no_third_party" 0 5 "uses numpy/scipy/sympy where pure-python suffices"
  else
    add "no_third_party" 1 5
  fi
else
  # File missing: still emit EVERY declared check as 0 so the denominator is
  # identical to a passing submission.
  for n in $BEHAVE_CHECKS; do add "$n" 0 "$(weight_for "$n")" "file_missing"; done
  add "no_third_party" 0 5 "file_missing"
fi

# emit
total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in ${checks[@]+"${checks[@]}"}; do
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
