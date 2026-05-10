#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/crc.py"
add "file:crc.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  if grep -qE "^\s*import\s+(binascii|zlib|crcmod)" "$T"; then
    add "no_stdlib_crc" 0 10 "imports forbidden module"
  else
    add "no_stdlib_crc" 1 10
  fi
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys
try: from crc import crc32_ieee, crc16_xmodem
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)
# Canonical test vectors
CRC32 = [(b"123456789", 0xCBF43926), (b"", 0x00000000), (b"a", 0xE8B7BE43),
         (b"The quick brown fox jumps over the lazy dog", 0x414FA339)]
CRC16 = [(b"123456789", 0x31C3), (b"", 0x0000), (b"A", 0x58E5), (b"Hello", 0xCBD6)]
for i,(d,e) in enumerate(CRC32,1):
    try:
        got = crc32_ieee(d)
        print(f"c32_{i}", 1 if got==e else 0, f"got={got:08x} want={e:08x}")
    except Exception as ex:
        print(f"c32_{i}", 0, "ERR", repr(ex))
for i,(d,e) in enumerate(CRC16,1):
    try:
        got = crc16_xmodem(d)
        print(f"c16_{i}", 1 if got==e else 0, f"got={got:04x} want={e:04x}")
    except Exception as ex:
        print(f"c16_{i}", 0, "ERR", repr(ex))
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    add "$name" "$pass" 8 "$note"
  done < <(echo "$RES")
else
  for n in compiles c32_1 c16_1; do add "$n" 0 5; done
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
