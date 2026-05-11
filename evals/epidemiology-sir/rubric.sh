#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

F="$WS/sir.py"
add "file:sir.py" "$([[ -f "$F" ]] && echo 1 || echo 0)" 5

if [[ -f "$F" ]]; then
  RES=$(python3 - "$WS" <<'PY' 2>&1
import sys, importlib.util
ws = sys.argv[1]
spec = importlib.util.spec_from_file_location("sir", f"{ws}/sir.py")
mod  = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
except Exception as e:
    print(f"IMPORT_ERROR: {repr(e)[:120]}"); sys.exit(0)

try:
    hist = mod.sir_rk4(S0=999.0, I0=1.0, R0=0.0, beta=0.3, gamma=0.1, t_end=160.0, dt=0.1)
except Exception as e:
    print(f"RUN_ERROR: {repr(e)[:120]}"); sys.exit(0)

if not isinstance(hist, list) or len(hist) < 100:
    print(f"HISTORY_TOO_SHORT: len={len(hist) if hasattr(hist,'__len__') else '?'}"); sys.exit(0)

# Verify structure
try:
    t0, s0, i0, r0 = hist[0]
    tn, sn, ifin, rn = hist[-1]
except Exception as e:
    print(f"BAD_TUPLE_SHAPE: {repr(e)[:120]}"); sys.exit(0)

# Conservation
N0 = s0 + i0 + r0
max_drift = max(abs((s+i+r) - N0) for (_, s, i, r) in hist)

# Peak infection
try:
    t_peak, i_peak = mod.peak_infection_day(hist)
except Exception as e:
    print(f"PEAK_ERROR: {repr(e)[:120]}"); sys.exit(0)

print(f"len={len(hist)} t_end={tn:.1f} N_drift={max_drift:.3f} t_peak={t_peak:.1f} i_peak={i_peak:.1f} R_final={rn:.1f}")
PY
)
  echo "DEBUG: $RES" >&2

  if echo "$RES" | grep -qE "IMPORT_ERROR|RUN_ERROR|HISTORY_TOO_SHORT|BAD_TUPLE_SHAPE|PEAK_ERROR"; then
    note=$(echo "$RES" | head -1 | tr -d '\n' | cut -c1-120)
    add "imports_and_runs" 0 15 "$note"
  else
    add "imports_and_runs" 1 15

    drift=$(echo "$RES" | grep -oE 'N_drift=[0-9.]+' | cut -d= -f2)
    if python3 -c "import sys; sys.exit(0 if float('$drift')<1.0 else 1)" 2>/dev/null; then
      add "conservation_S+I+R" 1 15 "drift=$drift"
    else
      add "conservation_S+I+R" 0 15 "drift=$drift"
    fi

    # β=0.3, γ=0.1, N=1000 → R₀=3, peak when S=γN/β=333; well-known values:
    # t_peak ≈ 38.4 days, I_peak ≈ 300, R_final ≈ 940
    tpeak=$(echo "$RES" | grep -oE 't_peak=[0-9.]+' | cut -d= -f2)
    if python3 -c "import sys; v=float('$tpeak'); sys.exit(0 if abs(v-38)<=5 else 1)" 2>/dev/null; then
      add "peak_day~38" 1 20 "t_peak=$tpeak"
    else
      add "peak_day~38" 0 20 "t_peak=$tpeak"
    fi

    ipeak=$(echo "$RES" | grep -oE 'i_peak=[0-9.]+' | cut -d= -f2)
    if python3 -c "import sys; v=float('$ipeak'); sys.exit(0 if abs(v-300)<=30 else 1)" 2>/dev/null; then
      add "peak_infected~300" 1 20 "i_peak=$ipeak"
    else
      add "peak_infected~300" 0 20 "i_peak=$ipeak"
    fi

    rfin=$(echo "$RES" | grep -oE 'R_final=[0-9.]+' | cut -d= -f2)
    if python3 -c "import sys; v=float('$rfin'); sys.exit(0 if abs(v-940)<=30 else 1)" 2>/dev/null; then
      add "R_final~940" 1 20 "R_final=$rfin"
    else
      add "R_final~940" 0 20 "R_final=$rfin"
    fi

    tend=$(echo "$RES" | grep -oE 't_end=[0-9.]+' | cut -d= -f2)
    if python3 -c "import sys; v=float('$tend'); sys.exit(0 if v>=159.9 else 1)" 2>/dev/null; then
      add "integrated_to_t_end" 1 5
    else
      add "integrated_to_t_end" 0 5 "t_end=$tend"
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
