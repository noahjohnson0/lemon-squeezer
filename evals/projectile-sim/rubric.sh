#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/projectile.py"
add "file:projectile.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5

  # Helper: parse the 3-line output
  parse_out() {
    python3 -c "
import sys, re
text = sys.argv[1]
out = {}
for line in text.splitlines():
    m = re.match(r'^(\w+)\s+(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)$', line.strip())
    if m: out[m.group(1)] = float(m.group(2))
print(out.get('range_m','None'), out.get('max_height_m','None'), out.get('flight_time_s','None'))
" "$1"
  }

  # Test 1: no-drag, v0=50, theta=45 — analytic range = 50^2*sin(90)/9.81 = 254.842
  OUT1=$(cd "$WS" && gtimeout 30 python3 projectile.py 50 45 0 0.01 1 2>&1 || true)
  read R1 H1 T1 < <(parse_out "$OUT1")
  # range tolerance: 0.5%
  py_check_close() {
    python3 -c "
import sys
got, want, tol = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
try: got = float(got)
except: print(0); sys.exit()
print(1 if abs(got-want)/abs(want) < tol else 0)
" "$1" "$2" "$3"
  }
  add "no_drag:range_correct" "$(py_check_close "$R1" "254.842" "0.005")" 15 "got R=$R1 want ~254.842 (analytic)"
  # max height analytic = (v0*sin(theta))^2/(2g) = (50*0.7071)^2/19.62 = 63.71
  add "no_drag:max_height_correct" "$(py_check_close "$H1" "63.711" "0.01")" 10 "got H=$H1 want ~63.711"
  # flight time analytic = 2*v0*sin(theta)/g = 7.207
  add "no_drag:flight_time_correct" "$(py_check_close "$T1" "7.207" "0.01")" 10 "got T=$T1 want ~7.207"

  # Test 2: WITH drag — range MUST be less than no-drag analytic
  OUT2=$(cd "$WS" && gtimeout 30 python3 projectile.py 50 45 0.47 0.01 1 2>&1 || true)
  read R2 H2 T2 < <(parse_out "$OUT2")
  add "drag:range_smaller_than_nodrag" "$(python3 -c "
try: r2=float('$R2'); print(1 if 50 < r2 < 254 else 0)
except: print(0)
")" 10 "got R=$R2 (must be 50<R<254)"
  add "drag:height_smaller_than_nodrag" "$(python3 -c "
try: h2=float('$H2'); print(1 if 10 < h2 < 63 else 0)
except: print(0)
")" 5 "got H=$H2"

  # Test 3: very heavy drag — range must collapse further
  OUT3=$(cd "$WS" && gtimeout 30 python3 projectile.py 50 45 2.0 0.05 0.5 2>&1 || true)
  read R3 H3 T3 < <(parse_out "$OUT3")
  add "heavy_drag:range_much_smaller" "$(python3 -c "
try: r2=float('$R2'); r3=float('$R3'); print(1 if r3 < r2 else 0)
except: print(0)
")" 10 "got R3=$R3, must be < R2=$R2"

  # RK4 marker — penalize obvious Euler. Look for k1, k2, k3, k4 multi-stage pattern.
  if grep -qE 'k1|k_1' "$T" && grep -qE 'k2|k_2' "$T" && grep -qE 'k3|k_3' "$T" && grep -qE 'k4|k_4' "$T"; then
    add "uses_rk4_pattern" 1 10
  else
    add "uses_rk4_pattern" 0 10 "no k1..k4 found"
  fi

  # Output format: 6-decimal places — check with regex on first run
  if echo "$OUT1" | grep -qE '^range_m [0-9]+\.[0-9]{6}$' && \
     echo "$OUT1" | grep -qE '^max_height_m [0-9]+\.[0-9]{6}$' && \
     echo "$OUT1" | grep -qE '^flight_time_s [0-9]+\.[0-9]{6}$'; then
    add "output:6dp_format" 1 5
  else
    add "output:6dp_format" 0 5 "first line: $(echo "$OUT1" | head -1)"
  fi
else
  for n in compiles no_drag:range_correct no_drag:max_height_correct no_drag:flight_time_correct \
           drag:range_smaller_than_nodrag drag:height_smaller_than_nodrag heavy_drag:range_much_smaller \
           uses_rk4_pattern output:6dp_format; do
    add "$n" 0 5
  done
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
