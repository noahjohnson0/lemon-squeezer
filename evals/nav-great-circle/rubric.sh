#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

F="$WS/nav.py"
add "file:nav.py" "$([[ -f "$F" ]] && echo 1 || echo 0)" 5

if [[ -f "$F" ]]; then
  RES=$(python3 - "$WS" <<'PY' 2>&1
import sys, importlib.util
ws = sys.argv[1]
spec = importlib.util.spec_from_file_location("n", f"{ws}/nav.py")
mod  = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
except Exception as e:
    print(f"IMPORT_ERROR: {repr(e)[:120]}"); sys.exit(0)

def near(a, b, tol):
    return abs(a-b) <= tol

# NYC → London
try:
    d = mod.haversine_km(40.7128, -74.0060, 51.5074, -0.1278)
    b = mod.initial_bearing_deg(40.7128, -74.0060, 51.5074, -0.1278)
    nyc_d_ok = near(d, 5570, 50)
    nyc_b_ok = near(b, 51, 5)
    print(f"nyc_d={d:.1f} nyc_b={b:.1f}")
except Exception as e:
    print(f"nyc_err: {e!r}")
    nyc_d_ok = nyc_b_ok = False

# Tokyo → Sydney
try:
    d = mod.haversine_km(35.6762, 139.6503, -33.8688, 151.2093)
    b = mod.initial_bearing_deg(35.6762, 139.6503, -33.8688, 151.2093)
    tok_d_ok = near(d, 7825, 80)
    tok_b_ok = near(b, 170, 5)
    print(f"tok_d={d:.1f} tok_b={b:.1f}")
except Exception as e:
    print(f"tok_err: {e!r}")
    tok_d_ok = tok_b_ok = False

# Zero distance
try:
    z = mod.haversine_km(0, 0, 0, 0)
    zero_ok = abs(z) < 1e-6
except Exception:
    zero_ok = False

# Cardinal lookup
card_cases = [(0, "N"), (45, "NE"), (90, "E"), (135, "SE"),
              (180, "S"), (225, "SW"), (270, "W"), (315, "NW"),
              (359, "N"), (22.5, "NNE"), (67.5, "ENE")]
ok = 0
for (b, exp) in card_cases:
    try:
        if mod.cardinal(b) == exp: ok += 1
    except Exception: pass
print(f"cards={ok}/{len(card_cases)}")
print(f"nyc_d_ok={int(nyc_d_ok)} nyc_b_ok={int(nyc_b_ok)} tok_d_ok={int(tok_d_ok)} tok_b_ok={int(tok_b_ok)} zero={int(zero_ok)}")
PY
)
  echo "DEBUG: $RES" >&2

  if echo "$RES" | grep -q "IMPORT_ERROR"; then
    add "imports" 0 10 "$(echo "$RES" | head -1 | cut -c1-100)"
  else
    add "imports" 1 5
    echo "$RES" | grep -q "nyc_d_ok=1" && add "nyc_london_distance" 1 15 || add "nyc_london_distance" 0 15
    echo "$RES" | grep -q "nyc_b_ok=1" && add "nyc_london_bearing"  1 15 || add "nyc_london_bearing"  0 15
    echo "$RES" | grep -q "tok_d_ok=1" && add "tok_syd_distance"    1 15 || add "tok_syd_distance"    0 15
    echo "$RES" | grep -q "tok_b_ok=1" && add "tok_syd_bearing"     1 15 || add "tok_syd_bearing"     0 15
    echo "$RES" | grep -q "zero=1"     && add "zero_distance"       1 5  || add "zero_distance"       0 5
    cn=$(echo "$RES" | grep -oE 'cards=[0-9]+' | cut -d= -f2)
    if   [[ "${cn:-0}" -ge 11 ]]; then add "cardinal_lookup"   1 30 "$cn/11"
    elif [[ "${cn:-0}" -ge 8 ]];  then add "cardinal_lookup"   1 20 "$cn/11"
    elif [[ "${cn:-0}" -ge 4 ]];  then add "cardinal_lookup"   1 10 "$cn/11"
    else                               add "cardinal_lookup"   0 30 "$cn/11"
    fi
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
