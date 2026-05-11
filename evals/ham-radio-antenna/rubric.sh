#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

F="$WS/antenna.py"
add "file:antenna.py" "$([[ -f "$F" ]] && echo 1 || echo 0)" 5

if [[ -f "$F" ]]; then
  RES=$(python3 - "$WS" <<'PY' 2>&1
import sys, importlib.util
ws = sys.argv[1]
spec = importlib.util.spec_from_file_location("antenna", f"{ws}/antenna.py")
mod  = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
except Exception as e:
    print(f"IMPORT_ERROR: {repr(e)[:120]}"); sys.exit(0)

def near(a, b, tol=0.5): return abs(a-b) <= tol

# 14.250 MHz: wavelength ≈ 21.04 m
try:
    w = mod.wavelength_m(14.250)
    print(f"wl_14M={'1' if near(w, 21.04, 0.2) else '0'}: got={w:.3f}")
except Exception as e: print(f"wl_14M_err: {e!r}")

# 7.150 MHz dipole leg ≈ (300/7.15)/4 * 0.95 ≈ 9.96 m
try:
    leg = mod.dipole_leg_length(7.150)
    print(f"leg_7M={'1' if near(leg, 9.96, 0.2) else '0'}: got={leg:.3f}")
except Exception as e: print(f"leg_7M_err: {e!r}")

# 7.150 MHz dipole total ≈ 19.93 m
try:
    tot = mod.dipole_total_length(7.150)
    print(f"tot_7M={'1' if near(tot, 19.93, 0.3) else '0'}: got={tot:.3f}")
except Exception as e: print(f"tot_7M_err: {e!r}")

# 146.52 MHz quarter-wave vertical ≈ 0.486 m
try:
    qw = mod.quarter_wave_vertical_m(146.52)
    print(f"qw_146M={'1' if near(qw, 0.486, 0.03) else '0'}: got={qw:.4f}")
except Exception as e: print(f"qw_146M_err: {e!r}")

# Band lookups
band_cases = [(3.6, "80m"), (7.15, "40m"), (14.25, "20m"), (21.3, "15m"),
              (28.5, "10m"), (51.0, "6m"), (146.52, "2m"), (440.0, "70cm")]
ok = 0
for f, exp in band_cases:
    try:
        if mod.band_for_frequency(f) == exp: ok += 1
    except Exception: pass
print(f"bands={ok}/{len(band_cases)}")

# Out-of-band should raise
try:
    mod.band_for_frequency(2.0)
    print("oob=0")
except ValueError:
    print("oob=1")
except Exception:
    print("oob=0")
PY
)
  echo "DEBUG: $RES" >&2

  if echo "$RES" | grep -q "IMPORT_ERROR"; then
    note=$(echo "$RES" | head -1 | tr -d '\n' | cut -c1-120)
    add "imports" 0 10 "$note"
  else
    add "imports" 1 5
    echo "$RES" | grep -q "wl_14M=1"  && add "wavelength_14MHz"        1 10 || add "wavelength_14MHz"        0 10
    echo "$RES" | grep -q "leg_7M=1"  && add "dipole_leg_40m"          1 15 || add "dipole_leg_40m"          0 15
    echo "$RES" | grep -q "tot_7M=1"  && add "dipole_total_40m"        1 15 || add "dipole_total_40m"        0 15
    echo "$RES" | grep -q "qw_146M=1" && add "qtr_wave_2m_simplex"     1 15 || add "qtr_wave_2m_simplex"     0 15
    bn=$(echo "$RES" | grep -oE 'bands=[0-9]+' | cut -d= -f2)
    if   [[ "${bn:-0}" -ge 8 ]]; then add "all_8_bands_correct"     1 25 "$bn/8"
    elif [[ "${bn:-0}" -ge 6 ]]; then add "all_8_bands_correct"     1 15 "$bn/8 (partial)"
    elif [[ "${bn:-0}" -ge 4 ]]; then add "all_8_bands_correct"     1 8  "$bn/8 (partial)"
    else                              add "all_8_bands_correct"     0 25 "$bn/8"
    fi
    echo "$RES" | grep -q "oob=1" && add "raises_on_oob_freq" 1 10 || add "raises_on_oob_freq" 0 10
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
