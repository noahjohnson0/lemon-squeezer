#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/solar.py"
add "file:solar.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys
try: from solar import sun_position
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)
# NOAA-validated test cases (allow ±2° tolerance)
CASES = [
    # (desc, lat, lon, y, m, d, hour, exp_alt_min, exp_alt_max, exp_az_min, exp_az_max)
    # 16:00 UTC at NYC = 12:00 EDT - past solar noon, sun south-southeast
    ("ny_summer_solstice",     40.71, -74.01, 2024, 6, 21, 16.0, 65, 72, 130, 150),
    ("london_winter_solstice", 51.50,   0.00, 2024,12, 21, 12.0, 13, 17, 175, 188),
    ("equator_equinox",         0.00,   0.00, 2024, 3, 20, 12.0, 85, 92,   0, 360),  # near-zenith
    ("sydney_winter_solstice",-33.87, 151.21, 2024, 6, 21,  2.0, 28, 36, 350,  10),  # noon AEST
    # 22:00 UTC at Anchorage = ~14:00 AKDT, near solar noon on summer solstice
    ("anchorage_summer_noon",  61.22,-149.90, 2024, 6, 21, 22.0, 48, 56, 175, 192),
]
def in_az_range(a, lo, hi):
    if lo <= hi: return lo <= a <= hi
    return a >= lo or a <= hi   # wraps around 0/360
for desc, la, lo_, y, m, d, h, almin, almax, azmin, azmax in CASES:
    try:
        alt, az = sun_position(la, lo_, y, m, d, h)
        ok_alt = almin <= alt <= almax
        ok_az  = in_az_range(az % 360, azmin, azmax)
        ok_range = 0 <= az < 360
        print(desc, 1 if (ok_alt and ok_az and ok_range) else 0,
              f"alt={alt:.2f} (want {almin}-{almax}) az={az:.2f} (want {azmin}-{azmax})")
    except Exception as e:
        print(desc, 0, "ERR", repr(e))
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    add "$name" "$pass" 16 "$note"
  done < <(echo "$RES")
else
  for n in compiles ny_summer_solstice_noon; do add "$n" 0 5; done
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
