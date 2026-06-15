#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/engineering.py"
add "file:engineering.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5

  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys
try:
    from engineering import reynolds, beam_deflection_max, rc_time_constant, voltage_divider
except Exception as e:
    print("IMPORT_ERR", e); sys.exit(1)

def near(a, b, tol):
    try: return abs(float(a) - float(b)) / max(abs(float(b)), 1e-12) < tol
    except: return False

# Reynolds - water at 20°C: rho=998, mu=1.002e-3, water in 25mm pipe at 1 m/s
print("re_water_pipe",   1 if near(reynolds(998, 1.0, 0.025, 1.002e-3), 24900, 0.01) else 0,
      "got", reynolds(998, 1.0, 0.025, 1.002e-3))
# Air over a wing: rho=1.225, mu=1.81e-5, v=50, L=2 -> ~6.77e6
print("re_air_wing",     1 if near(reynolds(1.225, 50, 2.0, 1.81e-5), 6767955, 0.01) else 0,
      "got", reynolds(1.225, 50, 2.0, 1.81e-5))
# Laminar threshold: rho=1000, mu=1e-3, v=0.001, L=0.001 -> Re=1
print("re_unit",         1 if near(reynolds(1000, 0.001, 0.001, 1e-3), 1.0, 0.001) else 0,
      "got", reynolds(1000, 0.001, 0.001, 1e-3))

# Beam deflection - steel I-beam, P=10kN, L=4m, E=200e9, I=8.33e-6
# delta = 10000 * 4^3 / (48 * 200e9 * 8.33e-6) = 640000 / 79968000 ≈ 0.008003
print("beam_steel",      1 if near(beam_deflection_max(10000, 4, 200e9, 8.33e-6), 0.008003, 0.01) else 0,
      "got", beam_deflection_max(10000, 4, 200e9, 8.33e-6))
# Pure-formula check: P=L=E=I=1, expect 1/48
print("beam_unit",       1 if near(beam_deflection_max(1, 1, 1, 1), 1/48, 0.001) else 0,
      "got", beam_deflection_max(1, 1, 1, 1))

# RC tau
print("rc_tau_1uF",      1 if near(rc_time_constant(1000, 1e-6), 0.001, 0.001) else 0,
      "got", rc_time_constant(1000, 1e-6))
print("rc_tau_big",      1 if near(rc_time_constant(1e6, 470e-6), 470, 0.001) else 0,
      "got", rc_time_constant(1e6, 470e-6))

# Voltage divider - 9V across two equal Rs -> 4.5V midpoint
print("vd_equal",        1 if near(voltage_divider(9.0, 1000, 1000), 4.5, 0.001) else 0,
      "got", voltage_divider(9.0, 1000, 1000))
# 12V, R1=10k, R2=1k -> 12 * 1k/11k = 1.0909
print("vd_1k_10k",       1 if near(voltage_divider(12.0, 10000, 1000), 1.0909, 0.001) else 0,
      "got", voltage_divider(12.0, 10000, 1000))
# Edge: zero R2 -> zero out
print("vd_zero_r2",      1 if near(voltage_divider(5.0, 1000, 0), 0.0, 1e-9) else 0,
      "got", voltage_divider(5.0, 1000, 0))
PY
)
  echo "$RES" >&2
  weight_for() { case "$1" in
    re_*)    echo 8;;
    beam_*)  echo 9;;
    rc_*)    echo 6;;
    vd_*)    echo 6;;
    *)       echo 5;;
  esac; }
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    add "$name" "$pass" "$(weight_for "$name")" "$note"
  done < <(echo "$RES")

  # Static check - no third-party imports
  if grep -qE "^\s*import\s+(numpy|scipy|sympy)" "$T"; then
    add "no_third_party" 0 5 "uses numpy/scipy/sympy where pure-python suffices"
  else
    add "no_third_party" 1 5
  fi
else
  for n in compiles re_water_pipe beam_steel rc_tau_1uF vd_equal no_third_party; do add "$n" 0 5; done
fi

# emit
total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in "${checks[@]}"; do
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
