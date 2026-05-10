#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/hamming.py"
add "file:hamming.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys
try: from hamming import encode, decode
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)
# Round-trip all 16 nibbles
ok_rt = 0
for x in range(16):
    try:
        c = encode(x)
        d, e = decode(c)
        if d == x and e == 0: ok_rt += 1
    except: pass
print("round_trip", 1 if ok_rt == 16 else 0, f"{ok_rt}/16")
# Single-bit error correction (any nibble, any flip position)
ok_corr = 0; total = 0
for x in range(16):
    for k in range(7):
        total += 1
        try:
            c = encode(x) ^ (1 << k)
            d, e = decode(c)
            if d == x and e == k + 1: ok_corr += 1
        except: pass
print("single_bit_correct", 1 if ok_corr == total else 0, f"{ok_corr}/{total}")
# Specific known-good check
print("zero_round_trip", 1 if decode(encode(0)) == (0, 0) else 0)
print("max_round_trip",  1 if decode(encode(15)) == (15, 0) else 0)
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    if [[ "$name" == "single_bit_correct" ]]; then add "$name" "$pass" 30 "$note"
    elif [[ "$name" == "round_trip" ]]; then add "$name" "$pass" 25 "$note"
    else add "$name" "$pass" 5 "$note"
    fi
  done < <(echo "$RES")
else
  for n in compiles round_trip single_bit_correct; do add "$n" 0 5; done
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
