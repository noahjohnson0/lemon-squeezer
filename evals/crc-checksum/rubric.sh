#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  # Sanitize note: strip backslashes and replace double-quotes so the JSON stays valid.
  note="${note//\\/}"
  note="${note//\"/\'}"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/crc.py"
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:crc.py" "$file_ok" 5

# compiles
compile_ok=0
if [[ "$file_ok" == "1" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && compile_ok=1
fi
add "compiles" "$compile_ok" 5

# no_stdlib_crc: forbidden imports must be absent. A missing/non-compiling file
# trivially has no forbidden import, so this carries a small weight - the real
# scoring lives in the behavioral checks below. The denominator stays constant
# either way.
if [[ "$file_ok" == "1" ]] && grep -qE "^\s*import\s+(binascii|zlib|crcmod)" "$T"; then
  add "no_stdlib_crc" 0 5 "imports forbidden module"
elif [[ "$file_ok" == "1" ]] && grep -qE "^\s*from\s+(binascii|zlib|crcmod)\s+import" "$T"; then
  add "no_stdlib_crc" 0 5 "imports forbidden module"
else
  add "no_stdlib_crc" 1 5
fi

# Behavioral checks. The python ALWAYS emits one "name pass [note]" line per
# declared check (chk() never aborts, never sys.exit), so the set of emitted
# checks - and therefore the denominator - is identical for an empty stub, an
# import-error file, a partial impl, or a fully correct one.
RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>>/dev/null
import sys

ok = True
crc32_ieee = crc16_xmodem = None
try:
    from crc import crc32_ieee, crc16_xmodem
except Exception as e:
    print("IMPORT_ERR", repr(e)[:80], file=sys.stderr)
    ok = False

# Explicit imports check: penalizes a non-importing file directly.
print("imports", 1 if ok else 0)

def chk(name, fn):
    if not ok:
        print(name, 0)
        return
    try:
        print(name, 1 if fn() else 0)
    except Exception as ex:
        print(name, 0, repr(ex)[:50])

# Canonical test vectors
CRC32 = [(b"123456789", 0xCBF43926), (b"", 0x00000000), (b"a", 0xE8B7BE43),
         (b"The quick brown fox jumps over the lazy dog", 0x414FA339)]
CRC16 = [(b"123456789", 0x31C3), (b"", 0x0000), (b"A", 0x58E5), (b"Hello", 0xCBD6)]

for i, (d, e) in enumerate(CRC32, 1):
    chk(f"c32_{i}", (lambda d=d, e=e: crc32_ieee(d) == e))
for i, (d, e) in enumerate(CRC16, 1):
    chk(f"c16_{i}", (lambda d=d, e=e: crc16_xmodem(d) == e))
PY
)
rc=$?
echo "behavioral python rc=$rc" >&2
echo "$RES" >&2

# Declare the behavioral checks we REQUIRE. If python crashed entirely (e.g.
# segfault / gtimeout kill) and a line is missing, we still emit that check as 0
# so the denominator never shrinks.
declare -A seen=()
declare -A bweight=( [imports]=8 [c32_1]=8 [c32_2]=8 [c32_3]=8 [c32_4]=8 \
                     [c16_1]=8 [c16_2]=8 [c16_3]=8 [c16_4]=8 )
declare -a order=( imports c32_1 c32_2 c32_3 c32_4 c16_1 c16_2 c16_3 c16_4 )

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  [[ "$name" == "IMPORT_ERR" ]] && continue
  [[ -z "${bweight[$name]+x}" ]] && continue   # ignore unexpected lines
  seen[$name]=1
  add "$name" "$pass" "${bweight[$name]}" "$note"
done < <(printf '%s\n' "$RES")

# Emit any required behavioral check that did NOT appear, as a hard 0.
for n in "${order[@]}"; do
  [[ -z "${seen[$n]+x}" ]] && add "$n" 0 "${bweight[$n]}" "check did not run"
done

total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in ${checks[@]+"${checks[@]}"}; do
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
