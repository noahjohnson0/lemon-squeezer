#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  # sanitize note: strip backslashes and replace double-quotes so the JSON stays valid
  note="${note//\\/}"
  note="${note//\"/\'}"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/hamming.py"

# --- static checks (always emitted) ---
add "file:hamming.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]] && python3 -m py_compile "$T" 2>/dev/null; then
  add "compiles" 1 5
else
  add "compiles" 0 5
fi

# --- behavioral checks ---
# The python ALWAYS prints exactly one line per declared check ("name pass [note]"),
# even on import failure or per-case exception. chk() never aborts, so the set of
# emitted checks - and therefore the denominator - is CONSTANT for every submission.
RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>/dev/null
import sys

ok = True
try:
    from hamming import encode, decode
except Exception as e:
    print("IMPORT_ERR", repr(e)[:80], file=sys.stderr)
    ok = False

def chk(name, fn):
    if not ok:
        print(name, 0, "no_import")
        return
    try:
        print(name, 1 if fn() else 0)
    except Exception as ex:
        print(name, 0, repr(ex)[:50])

# import flag check
print("imports", 1 if ok else 0)

# Round-trip all 16 nibbles
def round_trip():
    for x in range(16):
        c = encode(x)
        d, e = decode(c)
        if not (d == x and e == 0):
            return False
    return True
chk("round_trip", round_trip)

# Single-bit error correction (any nibble, any flip position)
def single_bit_correct():
    for x in range(16):
        for k in range(7):
            c = encode(x) ^ (1 << k)
            d, e = decode(c)
            if not (d == x and e == k + 1):
                return False
    return True
chk("single_bit_correct", single_bit_correct)

# Specific known-good checks
chk("zero_round_trip", lambda: decode(encode(0)) == (0, 0))
chk("max_round_trip",  lambda: decode(encode(15)) == (15, 0))
PY
)
rc=$?
echo "$RES" >&2

# Map each declared behavioral check to its weight. Pre-seed every expected name
# as a 0 so that even if the python crashed wholesale (timeout/segfault) and
# emitted NOTHING, the denominator is still constant.
declare -A bweight=( [imports]=5 [round_trip]=25 [single_bit_correct]=30 [zero_round_trip]=5 [max_round_trip]=5 )
declare -A bpass=()
declare -A bnote=()
for n in "${!bweight[@]}"; do bpass["$n"]=0; bnote["$n"]=""; done

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  [[ "$name" == "IMPORT_ERR" ]] && continue
  # only honor names we declared; ignore stray stdout
  if [[ -n "${bweight[$name]+x}" ]]; then
    bpass["$name"]="$pass"
    bnote["$name"]="$note"
  fi
done < <(printf '%s\n' "$RES")

# emit behavioral checks in a stable order
for n in imports round_trip single_bit_correct zero_round_trip max_round_trip; do
  add "$n" "${bpass[$n]}" "${bweight[$n]}" "${bnote[$n]}"
done

# --- emit JSON (the ONLY thing on stdout) ---
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
