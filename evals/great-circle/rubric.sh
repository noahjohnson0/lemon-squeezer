#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/geo.py"
add "file:geo.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5

  RES=$(cd "$WS" && gtimeout 5 python3 - <<'PY' 2>&1
import sys
try:
    from geo import distance_km, bearing_deg
except Exception as e:
    print("IMPORT_ERR", e); sys.exit(1)

def near(a, b, tol):
    try: return abs(float(a) - float(b)) <= tol
    except: return False

# Cases: (lat1, lon1, lat2, lon2, expected_km, expected_bearing)
CASES = [
    # NYC -> London
    (40.7128, -74.0060, 51.5074, -0.1278, 5570.23, 51.21),
    # SF -> Tokyo
    (37.7749, -122.4194, 35.6762, 139.6503, 8274.63, 303.36),
    # Sydney -> Auckland
    (-33.8688, 151.2093, -36.8485, 174.7633, 2155.90, 105.58),
    # Equator antipodal
    (0, 0, 0, 180, 20015.11, 90.00),
    # Pole to equator on prime meridian
    (90, 0, 0, 0, 10007.56, 180.00),
    # Same point
    (45, -93, 45, -93, 0.00, None),  # bearing N/A but should not crash
    # Quito -> Singapore
    (-0.1807, -78.4678, 1.3521, 103.8198, 19729.36, 297.13),
]

for i, (la1, lo1, la2, lo2, ed, eb) in enumerate(CASES, 1):
    try:
        d = distance_km(la1, lo1, la2, lo2)
        b = bearing_deg(la1, lo1, la2, lo2)
        ok_d = near(d, ed, 5.0)              # ±5 km on great-circle
        ok_b = (eb is None) or near(b, eb, 1.0) or near(((b%360)-eb)%360, 0, 1.0)
        # bearing must be in [0,360)
        ok_range = (0 <= b < 360)
        print(f"c{i}_dist", 1 if ok_d else 0, "got", round(d,2))
        print(f"c{i}_bear", 1 if (ok_b and ok_range) else 0, "got", round(b,2))
    except Exception as e:
        print(f"c{i}_dist", 0, "ERR", repr(e))
        print(f"c{i}_bear", 0, "ERR", repr(e))
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    add "$name" "$pass" 6 "$note"
  done < <(echo "$RES")
else
  for n in compiles c1_dist c2_dist c3_dist; do add "$n" 0 5; done
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
