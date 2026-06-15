#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  # sanitize note: strip backslashes and replace double-quotes so the JSON stays valid
  note="${note//\\/}"
  note="${note//\"/\'}"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/solar.py"
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:solar.py" "$file_ok" 5

# compile check (0 when the file is missing or does not compile)
compile_ok=0
if [[ "$file_ok" == "1" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && compile_ok=1
fi
add "compiles" "$compile_ok" 5

# The python block ALWAYS prints exactly one line per declared check, even on
# import failure or per-case exceptions. This keeps the denominator constant:
# every behavioral case is emitted as "<name> <0|1> [note]" no matter what.
RES=$(cd "$WS" && gtimeout 20 python3 - <<'PY' 2>>/dev/null
import sys

ok = True
sun_position = None
try:
    from solar import sun_position
except Exception as e:
    print("IMPORT_ERR", repr(e)[:60], file=sys.stderr)
    ok = False

# emit the import flag as a real, always-present check line
print("imports", 1 if ok else 0)

# NOAA-validated test cases (alt/az tolerance baked into the ranges)
CASES = [
    # (desc, lat, lon, y, m, d, hour, exp_alt_min, exp_alt_max, exp_az_min, exp_az_max)
    ("ny_summer_solstice",     40.71, -74.01, 2024, 6, 21, 16.0, 65, 72, 130, 150),
    ("london_winter_solstice", 51.50,   0.00, 2024,12, 21, 12.0, 13, 17, 175, 188),
    ("equator_equinox",         0.00,   0.00, 2024, 3, 20, 12.0, 85, 92,   0, 360),
    ("sydney_winter_solstice",-33.87, 151.21, 2024, 6, 21,  2.0, 28, 36, 350,  10),
    ("anchorage_summer_noon",  61.22,-149.90, 2024, 6, 21, 22.0, 48, 56, 175, 192),
]

def in_az_range(a, lo, hi):
    if lo <= hi:
        return lo <= a <= hi
    return a >= lo or a <= hi  # wraps around 0/360

def run_case(la, lo_, y, m, d, h, almin, almax, azmin, azmax):
    alt, az = sun_position(la, lo_, y, m, d, h)
    ok_alt = almin <= alt <= almax
    ok_az = in_az_range(az % 360, azmin, azmax)
    ok_range = 0 <= az < 360
    note = "alt=%.2f (want %s-%s) az=%.2f (want %s-%s)" % (alt, almin, almax, az, azmin, azmax)
    return (ok_alt and ok_az and ok_range), note

def chk(name, args):
    # ALWAYS prints a line. Import failure or any exception -> pass 0.
    if not ok:
        print(name, 0, "no import")
        return
    try:
        passed, note = run_case(*args)
        print(name, 1 if passed else 0, note)
    except Exception as ex:
        print(name, 0, "ERR", repr(ex)[:50])

for desc, la, lo_, y, m, d, h, almin, almax, azmin, azmax in CASES:
    chk(desc, (la, lo_, y, m, d, h, almin, almax, azmin, azmax))
PY
)

# Dump diagnostics to stderr only; stdout is reserved for the final JSON.
echo "$RES" >&2

# Declare every behavioral check up front with its weight, defaulting to a
# failing (0) line. If the python block emitted a line for it, that overrides
# the default. This guarantees a CONSTANT denominator regardless of how broken
# the submission is (empty stub, import error, partial, or correct).
BEHAVIOR_NAMES=(imports ny_summer_solstice london_winter_solstice equator_equinox sydney_winter_solstice anchorage_summer_noon)
declare -A weight_of=(
  [imports]=10
  [ny_summer_solstice]=16
  [london_winter_solstice]=16
  [equator_equinox]=16
  [sydney_winter_solstice]=16
  [anchorage_summer_noon]=16
)
declare -A pass_of
declare -A note_of
for n in "${BEHAVIOR_NAMES[@]}"; do pass_of[$n]=0; note_of[$n]=""; done

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  [[ -z "${weight_of[$name]:-}" ]] && continue   # ignore unexpected lines
  pass_of[$name]="$pass"
  note_of[$name]="$note"
done < <(printf '%s\n' "$RES")

for n in "${BEHAVIOR_NAMES[@]}"; do
  add "$n" "${pass_of[$n]}" "${weight_of[$n]}" "${note_of[$n]}"
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
