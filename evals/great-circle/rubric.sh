#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
# sanitize: strip backslashes, turn double-quotes into single-quotes so the
# emitted JSON note string never breaks. (see CLAUDE.md rubric gotcha #2)
sanitize() { printf '%s' "$1" | tr -d '\\' | tr '"' "'"; }
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  note=$(sanitize "$note")
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/geo.py"
add "file:geo.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

# static: no third-party deps (only stdlib `math` allowed). This is a STATIC
# check that even a broken file can pass; it must not inflate the score, so the
# denominator below always carries the full behavioral suite regardless.
if [[ -f "$T" ]]; then
  if grep -Eq '^[[:space:]]*(import|from)[[:space:]]+(numpy|scipy|geopy|pyproj|pandas)' "$T"; then
    add "no_thirdparty" 0 3
  else
    add "no_thirdparty" 1 3
  fi
else
  add "no_thirdparty" 0 3
fi

# compiles
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
else
  add "compiles" 0 5
fi

# The behavioral suite. EVERY one of these names is ALWAYS scored (pass=1 or
# pass=0) so the denominator is constant no matter how broken the submission is.
# Order/weights matter: imports(8) + 7*(dist 6 + bear 6).
BEHAV_NAMES=(imports
  c1_dist c1_bear c2_dist c2_bear c3_dist c3_bear c4_dist c4_bear
  c5_dist c5_bear c6_dist c6_bear c7_dist c7_bear)
declare -A BEHAV_W=(
  [imports]=8
  [c1_dist]=6 [c1_bear]=6 [c2_dist]=6 [c2_bear]=6 [c3_dist]=6 [c3_bear]=6
  [c4_dist]=6 [c4_bear]=6 [c5_dist]=6 [c5_bear]=6 [c6_dist]=6 [c6_bear]=6
  [c7_dist]=6 [c7_bear]=6
)

RES=""
if [[ -f "$T" ]]; then
  RES=$(cd "$WS" && gtimeout 5 python3 - <<'PY'
import sys

ok = True
try:
    from geo import distance_km, bearing_deg
except Exception as e:
    print("IMPORT_ERR", repr(e)[:80], file=sys.stderr)
    ok = False

def chk(name, fn):
    # ALWAYS prints a line so the denominator stays constant.
    if not ok:
        print(name, 0, "no_import")
        return
    try:
        print(name, 1 if fn() else 0)
    except Exception as ex:
        print(name, 0, repr(ex)[:50])

def near(a, b, tol):
    try:
        return abs(float(a) - float(b)) <= tol
    except Exception:
        return False

# (lat1, lon1, lat2, lon2, expected_km, expected_bearing)
CASES = [
    (40.7128, -74.0060, 51.5074, -0.1278, 5570.23, 51.21),     # NYC -> London
    (37.7749, -122.4194, 35.6762, 139.6503, 8274.63, 303.36),  # SF -> Tokyo
    (-33.8688, 151.2093, -36.8485, 174.7633, 2155.90, 105.58), # Sydney -> Auckland
    (0, 0, 0, 180, 20015.11, 90.00),                           # equator antipodal
    (90, 0, 0, 0, 10007.56, 180.00),                           # pole -> equator
    (45, -93, 45, -93, 0.00, None),                            # same point
    (-0.1807, -78.4678, 1.3521, 103.8198, 19729.36, 297.13),   # Quito -> Singapore
]

print("imports", 1 if ok else 0)

for i, (la1, lo1, la2, lo2, ed, eb) in enumerate(CASES, 1):
    def dist_ok(la1=la1, lo1=lo1, la2=la2, lo2=lo2, ed=ed):
        return near(distance_km(la1, lo1, la2, lo2), ed, 5.0)

    def bear_ok(la1=la1, lo1=lo1, la2=la2, lo2=lo2, eb=eb):
        b = bearing_deg(la1, lo1, la2, lo2)
        if not (0 <= b < 360):
            return False
        if eb is None:
            return True
        # circular distance, tolerant of 0/360 wraparound
        return near(((b - eb + 180.0) % 360.0) - 180.0, 0.0, 1.0)

    chk(f"c{i}_dist", dist_ok)
    chk(f"c{i}_bear", bear_ok)
PY
)
fi
echo "$RES" >&2

# Build a name->"pass note" map from whatever python emitted.
declare -A GOT_PASS=()
declare -A GOT_NOTE=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  GOT_PASS["$name"]="$pass"
  GOT_NOTE["$name"]="$note"
done < <(printf '%s\n' "$RES")

# Add EVERY declared behavioral check exactly once. Missing/garbled => pass 0.
# This is what makes the denominator constant across stub/import-err/partial/ref.
for name in "${BEHAV_NAMES[@]}"; do
  p="${GOT_PASS[$name]:-0}"
  [[ "$p" != "1" ]] && p=0
  add "$name" "$p" "${BEHAV_W[$name]}" "${GOT_NOTE[$name]:-missing}"
done

# emit (ONLY the final JSON object goes to stdout)
total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in "${checks[@]+"${checks[@]}"}"; do
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
