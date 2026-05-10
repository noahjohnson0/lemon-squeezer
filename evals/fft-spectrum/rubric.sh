#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/spectrum.py"
add "file:spectrum.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  RES=$(cd "$WS" && gtimeout 15 python3 - <<'PY' 2>&1
import sys, math
try: from spectrum import magnitude_spectrum, dominant_freq
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)
# 50 Hz pure tone, fs=1000, N=1024 -> bin 51 (51*1000/1024=49.80 Hz)
fs, N = 1000.0, 1024
x = [math.sin(2*math.pi*50*n/fs) for n in range(N)]
try:
    f = dominant_freq(x, fs)
    bin_freq = 51 * fs / N
    print("dom_50hz", 1 if abs(f - bin_freq) < fs/N else 0, f"got={f:.3f} expected~{bin_freq:.3f}")
except Exception as e: print("dom_50hz", 0, repr(e))
# 440 Hz sine, fs=8000, N=4096 -> bin 225 (225*8000/4096=439.45)
fs2, N2 = 8000.0, 4096
x2 = [math.sin(2*math.pi*440*n/fs2) for n in range(N2)]
try:
    f = dominant_freq(x2, fs2)
    print("dom_440hz", 1 if abs(f - 439.45) < 1.0 else 0, f"got={f:.3f}")
except Exception as e: print("dom_440hz", 0, repr(e))
# DC offset + tone: must reject DC and find tone
x3 = [5.0 + 0.1*math.sin(2*math.pi*50*n/fs) for n in range(N)]
try:
    f = dominant_freq(x3, fs)
    print("dom_dc_reject", 1 if abs(f - 49.80) < 1.0 else 0, f"got={f:.3f}")
except Exception as e: print("dom_dc_reject", 0, repr(e))
# spectrum length = N//2+1
try:
    fr, mg = magnitude_spectrum(x, fs)
    print("spec_len",      1 if len(fr) == N//2+1 and len(mg) == N//2+1 else 0, f"got={len(fr)}")
    print("spec_first_dc", 1 if abs(fr[0] - 0.0) < 1e-9 else 0, f"got={fr[0]}")
    print("spec_last_nyq", 1 if abs(fr[-1] - fs/2) < 1e-3 else 0, f"got={fr[-1]}")
except Exception as e:
    for n in ["spec_len","spec_first_dc","spec_last_nyq"]: print(n, 0, repr(e))
# zero-length raises
try: magnitude_spectrum([], fs); print("empty_raises", 0)
except ValueError: print("empty_raises", 1)
except Exception as e: print("empty_raises", 0, repr(e))
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    add "$name" "$pass" 11 "$note"
  done < <(echo "$RES")
else
  for n in compiles dom_50hz spec_len; do add "$n" 0 5; done
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
