#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
sanitize() {
  # strip backslashes and replace double-quotes so notes never break the JSON
  printf '%s' "$1" | tr -d '\\' | tr '"' "'" | tr '\t\n' '  '
}
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  note="$(sanitize "$note")"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/kepler.py"
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:kepler.py" "$file_ok" 5

# compiles
compile_ok=0
if [[ "$file_ok" == "1" ]] && python3 -m py_compile "$T" 2>/dev/null; then
  compile_ok=1
fi
add "compiles" "$compile_ok" 5

# RK4 marker (static check) - only meaningful if the file exists
if [[ "$file_ok" == "1" ]] && \
   grep -qE 'k1|k_1' "$T" && grep -qE 'k2|k_2' "$T" && \
   grep -qE 'k3|k_3' "$T" && grep -qE 'k4|k_4' "$T"; then
  add "uses_rk4" 1 8
else
  add "uses_rk4" 0 8 "no k1..k4 in code"
fi

# ---- behavioral checks: python ALWAYS prints one line per declared check ----
# Even on import error or per-case exceptions, every name below is emitted as
# "<name> <0|1> [note]" so the denominator stays constant. The list of names
# and weights here is the single source of truth for the bash side.
RES=$(cd "$WS" && gtimeout 30 python3 - <<'PY' 2>/dev/null
import sys, math
ok = True
try:
    from kepler import simulate, total_energy
except Exception as e:
    print("IMPORT_ERR", repr(e), file=sys.stderr)
    ok = False
print("imports", 1 if ok else 0)
def near(a, b, tol):
    return abs(a - b) < tol
def chk(name, fn):
    if not ok:
        print(name, 0, "no import")
        return
    try:
        res = fn()
        if isinstance(res, tuple):
            passed, note = res
        else:
            passed, note = res, ""
        print(name, 1 if passed else 0, note)
    except Exception as ex:
        print(name, 0, repr(ex)[:60])

def c_energy_formula():
    E0 = total_energy(1, 0, 0, 1)
    return near(E0, -0.5, 1e-9), "got=%.6f" % E0
def c_half_period():
    x, y, vx, vy = simulate(1, 0, 0, 1, math.pi, 1e-3)
    return (near(x, -1, 0.05) and near(y, 0, 0.05)), "got=(%.3f,%.3f)" % (x, y)
def c_full_period():
    x, y, vx, vy = simulate(1, 0, 0, 1, 2 * math.pi, 1e-3)
    return (near(x, 1, 0.05) and near(y, 0, 0.05)), "got=(%.3f,%.3f)" % (x, y)
def c_energy_drift():
    x, y, vx, vy = simulate(1, 0, 0, 1, 2 * math.pi, 1e-3)
    drift = abs(total_energy(x, y, vx, vy) - (-0.5))
    return drift < 1e-3, "drift=%.6f" % drift
def c_ellipse_apo():
    # e=0.5, a=1: periapsis r=0.5 with v_perp=sqrt(2/0.5 - 1)=sqrt(3);
    # after half an orbit we reach apoapsis r_apo=a(1+e)=1.5
    x, y, vx, vy = simulate(0.5, 0, 0, math.sqrt(3), math.pi, 1e-3)
    r = math.sqrt(x * x + y * y)
    return near(r, 1.5, 0.05), "r=%.3f" % r

chk("energy_formula", c_energy_formula)
chk("half_period", c_half_period)
chk("full_period", c_full_period)
chk("energy_drift", c_energy_drift)
chk("ellipse_apo", c_ellipse_apo)
PY
)
echo "$RES" >&2

# Collect emitted behavioral lines into an associative map: name -> "pass note"
declare -A emitted
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  [[ "$name" == "IMPORT_ERR" ]] && continue
  [[ "$pass" != "1" ]] && pass=0
  emitted["$name"]="$pass	$note"
done < <(printf '%s\n' "$RES")

# Declared behavioral checks with fixed weights. Iterating this fixed list
# (NOT whatever python happened to print) guarantees a CONSTANT denominator:
# any check python failed to emit is scored 0 here rather than vanishing.
behavioral=(
  "imports:6"
  "energy_formula:8"
  "half_period:12"
  "ellipse_apo:12"
  "full_period:14"
  "energy_drift:14"
)
for spec in "${behavioral[@]}"; do
  name="${spec%%:*}"; w="${spec##*:}"
  if [[ -n "${emitted[$name]+x}" ]]; then
    IFS=$'\t' read -r p note <<<"${emitted[$name]}"
    add "$name" "$p" "$w" "$note"
  else
    add "$name" 0 "$w" "not emitted"
  fi
done

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
