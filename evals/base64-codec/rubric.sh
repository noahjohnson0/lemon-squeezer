#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/base64codec.py"
add "file:base64codec.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  if grep -qE "^\s*import\s+base64|from\s+base64" "$T"; then
    add "no_stdlib_base64" 0 10 "imports base64 module"
  else
    add "no_stdlib_base64" 1 10
  fi
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys
try: from base64codec import encode, decode
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)
CASES = [
    (b"", ""),
    (b"f", "Zg=="),
    (b"fo", "Zm8="),
    (b"foo", "Zm9v"),
    (b"foob", "Zm9vYg=="),
    (b"fooba", "Zm9vYmE="),
    (b"foobar", "Zm9vYmFy"),
    (b"Hello, World!", "SGVsbG8sIFdvcmxkIQ=="),
    (b"\x00\x01\x02\x03\xff", "AAECA/8="),
]
for i, (data, expected) in enumerate(CASES, 1):
    try:
        got = encode(data)
        ok_e = (got == expected)
        rt = decode(got)
        ok_d = (rt == data)
        print(f"enc{i}", 1 if ok_e else 0, "got", repr(got)[:60])
        print(f"rt{i}",  1 if ok_d else 0, "got", repr(rt)[:60])
    except Exception as e:
        print(f"enc{i}", 0, "ERR", repr(e))
        print(f"rt{i}",  0, "ERR", repr(e))
# decode invalid raises
try:
    decode("!!!!")
    print("rejects_invalid", 0, "no raise")
except ValueError:
    print("rejects_invalid", 1)
except Exception as e:
    print("rejects_invalid", 0, "wrong exception", repr(e))
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    add "$name" "$pass" 4 "$note"
  done < <(echo "$RES")
else
  for n in compiles enc1 rt1 rejects_invalid; do add "$n" 0 5; done
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
