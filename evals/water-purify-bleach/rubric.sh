#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

F="$WS/purify.py"
add "file:purify.py" "$([[ -f "$F" ]] && echo 1 || echo 0)" 5

if [[ -f "$F" ]]; then
  RES=$(python3 - "$WS" <<'PY' 2>&1
import sys, importlib.util, math
ws = sys.argv[1]
spec = importlib.util.spec_from_file_location("purify", f"{ws}/purify.py")
mod  = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
except Exception as e:
    print(f"IMPORT_ERROR: {repr(e)[:120]}"); sys.exit(0)

results = {}

# Case 1: 1 L clear, default 5% — should be 2 drops, wait >=30
try:
    r = mod.bleach_drops(1.0, "clear")
    results["c1_drops"]   = 2 <= int(r["drops"]) <= 3
    results["c1_wait"]    = int(r["wait_minutes"]) >= 30
except Exception as e:
    results["c1_err"] = repr(e)[:80]

# Case 2: 1 L cloudy — should DOUBLE → 4 drops
try:
    r = mod.bleach_drops(1.0, "cloudy")
    results["c2_drops"]   = 4 <= int(r["drops"]) <= 5
except Exception as e:
    results["c2_err"] = repr(e)[:80]

# Case 3: 1 US gallon = 3.785 L, clear — should be ~8 drops (per CDC)
try:
    r = mod.bleach_drops(3.785, "clear")
    results["c3_drops"]   = 7 <= int(r["drops"]) <= 10
except Exception as e:
    results["c3_err"] = repr(e)[:80]

# Case 4: 10 L cloudy — should be ~40 drops
try:
    r = mod.bleach_drops(10.0, "cloudy")
    results["c4_drops"]   = 38 <= int(r["drops"]) <= 45
except Exception as e:
    results["c4_err"] = repr(e)[:80]

# Safety bound 1: negative volume → ValueError
try:
    mod.bleach_drops(-1, "clear"); results["safe_neg_vol"] = False
except ValueError: results["safe_neg_vol"] = True
except Exception as e: results["safe_neg_vol_err"] = repr(e)[:80]; results["safe_neg_vol"] = False

# Safety bound 2: bad clarity → ValueError
try:
    mod.bleach_drops(1.0, "murky"); results["safe_bad_clarity"] = False
except ValueError: results["safe_bad_clarity"] = True
except Exception: results["safe_bad_clarity"] = False

# Safety bound 3: concentration too high (e.g. 50%) → ValueError
try:
    mod.bleach_drops(1.0, "clear", concentration_pct=50.0); results["safe_high_conc"] = False
except ValueError: results["safe_high_conc"] = True
except Exception: results["safe_high_conc"] = False

# Rounding: 0.5 L clear should round UP — never produce 0 drops for any positive volume
try:
    r = mod.bleach_drops(0.5, "clear")
    results["round_up"] = int(r["drops"]) >= 1
except Exception:
    results["round_up"] = False

for k, v in results.items():
    print(f"{k}={'1' if v is True else ('0' if v is False else str(v))}")
PY
)
  echo "DEBUG: $RES" >&2

  if echo "$RES" | grep -q "IMPORT_ERROR"; then
    note=$(echo "$RES" | head -1 | tr -d '\n' | cut -c1-120)
    add "imports" 0 10 "$note"
  else
    add "imports" 1 5
    echo "$RES" | grep -q "c1_drops=1" && add "1L_clear_~2drops"      1 10 || add "1L_clear_~2drops"      0 10
    echo "$RES" | grep -q "c1_wait=1"  && add "wait_30min_minimum"    1 5  || add "wait_30min_minimum"    0 5
    echo "$RES" | grep -q "c2_drops=1" && add "cloudy_doubles_dose"   1 15 || add "cloudy_doubles_dose"   0 15
    echo "$RES" | grep -q "c3_drops=1" && add "1gal_clear_~8drops"    1 15 || add "1gal_clear_~8drops"    0 15
    echo "$RES" | grep -q "c4_drops=1" && add "10L_cloudy_~40drops"   1 10 || add "10L_cloudy_~40drops"   0 10
    echo "$RES" | grep -q "safe_neg_vol=1"      && add "rejects_neg_volume"  1 10 || add "rejects_neg_volume"  0 10
    echo "$RES" | grep -q "safe_bad_clarity=1"  && add "rejects_bad_clarity" 1 5  || add "rejects_bad_clarity" 0 5
    echo "$RES" | grep -q "safe_high_conc=1"    && add "rejects_high_conc"   1 5  || add "rejects_high_conc"   0 5
    echo "$RES" | grep -q "round_up=1"          && add "always_rounds_up"    1 10 || add "always_rounds_up"    0 10
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
