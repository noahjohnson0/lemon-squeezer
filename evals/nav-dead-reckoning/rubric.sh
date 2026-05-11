#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

F="$WS/reckon.py"
add "file:reckon.py" "$([[ -f "$F" ]] && echo 1 || echo 0)" 5

if [[ -f "$F" ]]; then
  RES=$(python3 - "$WS" <<'PY' 2>&1
import sys, importlib.util, math
ws = sys.argv[1]
spec = importlib.util.spec_from_file_location("r", f"{ws}/reckon.py")
mod  = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
except Exception as e:
    print(f"IMPORT_ERROR: {repr(e)[:120]}"); sys.exit(0)

def near(a, b, tol):
    return abs(a-b) <= tol

# 1. (40, -74) east at 10 kt for 1 hour → approx (40.0, -73.782)
try:
    la, lo = mod.dead_reckon(40.0, -74.0, 90, 10, 1.0)
    east_ok = near(la, 40.0, 0.05) and near(lo, -73.782, 0.05)
    print(f"east la={la:.4f} lo={lo:.4f}")
except Exception as e:
    print(f"east_err: {e!r}")
    east_ok = False

# 2. (0, 0) north at 60 kt for 1 hour → ~1° lat (60 nm = ~111 km = 1° lat)
try:
    la, lo = mod.dead_reckon(0.0, 0.0, 0, 60, 1.0)
    north_ok = near(la, 1.0, 0.05) and near(lo, 0.0, 0.02)
    print(f"north la={la:.4f} lo={lo:.4f}")
except Exception as e:
    print(f"north_err: {e!r}")
    north_ok = False

# 3. (0, 179) east at 60 kt for 1 hour → wraps around to approx (0, -179)
try:
    la, lo = mod.dead_reckon(0.0, 179.0, 90, 60, 1.0)
    wrap_ok = -180 <= lo < 180 and (la == 0.0 or near(la, 0.0, 0.05))
    # Should have crossed antimeridian
    wrap_correct = lo < -179 or near(lo, -179.0, 1.0) or near(lo, 180.0, 1.0)
    print(f"wrap la={la:.4f} lo={lo:.4f}")
except Exception as e:
    print(f"wrap_err: {e!r}")
    wrap_ok = wrap_correct = False

# 4. Multi-leg track
try:
    legs = [(90, 10, 1.0), (0, 10, 1.0)]
    track = mod.reckon_track((40.0, -74.0), legs)
    track_len_ok = len(track) == 3  # start + 2 legs
    # After east 10kt 1h then north 10kt 1h: lat goes up by ~10 nm
    last_la, last_lo = track[-1]
    final_ok = near(last_la, 40.0 + 10/60, 0.1) and near(last_lo, -73.782, 0.1)
    print(f"track_len={len(track)} final=({last_la:.4f},{last_lo:.4f})")
except Exception as e:
    print(f"track_err: {e!r}")
    track_len_ok = final_ok = False

print(f"east_ok={int(east_ok)} north_ok={int(north_ok)} wrap_ok={int(wrap_ok and wrap_correct)} track_len_ok={int(track_len_ok)} final_ok={int(final_ok)}")
PY
)
  echo "DEBUG: $RES" >&2

  if echo "$RES" | grep -q "IMPORT_ERROR"; then
    add "imports" 0 10 "$(echo "$RES" | head -1 | cut -c1-100)"
  else
    add "imports" 1 5
    echo "$RES" | grep -q "east_ok=1"      && add "east_10kt_1h"     1 20 || add "east_10kt_1h"     0 20
    echo "$RES" | grep -q "north_ok=1"     && add "north_60kt_1h_=1°" 1 20 || add "north_60kt_1h_=1°" 0 20
    echo "$RES" | grep -q "wrap_ok=1"      && add "antimeridian_wrap" 1 15 || add "antimeridian_wrap" 0 15
    echo "$RES" | grep -q "track_len_ok=1" && add "track_includes_start" 1 15 || add "track_includes_start" 0 15
    echo "$RES" | grep -q "final_ok=1"     && add "multi_leg_track"   1 25 || add "multi_leg_track"   0 25
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
