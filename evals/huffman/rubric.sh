#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/huffman.py"
add "file:huffman.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys
try: from huffman import build_codes, encode, decode
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)
TEXTS = ["a", "ab", "hello world", "AAAAABCD",
         "the quick brown fox jumps over the lazy dog",
         "mississippi", "abracadabra"*5]
for i,t in enumerate(TEXTS,1):
    try:
        c = build_codes(t)
        e = encode(t, c)
        d = decode(e, c)
        rt_ok = (d == t)
        # length check: encoded bitstring length matches sum of code lengths
        expected_len = sum(len(c[ch]) for ch in t)
        len_ok = (len(e) == expected_len)
        # all codes must be valid bitstrings
        codes_ok = all(set(v) <= {'0','1'} and len(v) > 0 for v in c.values())
        # prefix-free check (no code is prefix of another)
        vals = list(c.values())
        prefix_ok = all(not (a != b and a.startswith(b)) for a in vals for b in vals)
        print(f"t{i}_rt", 1 if rt_ok else 0, f"len_in={len(t)} bits={len(e)}")
        print(f"t{i}_len", 1 if len_ok else 0)
        print(f"t{i}_prefix", 1 if prefix_ok else 0)
    except Exception as e:
        print(f"t{i}_rt", 0, "ERR", repr(e))
        print(f"t{i}_len", 0, "ERR")
        print(f"t{i}_prefix", 0, "ERR")
# Empty handling
try:
    c = build_codes("")
    print("empty_codes", 1 if c == {} else 0)
    print("empty_encode", 1 if encode("", c) == "" else 0)
    print("empty_decode", 1 if decode("", c) == "" else 0)
except Exception as e:
    for n in ["empty_codes","empty_encode","empty_decode"]: print(n, 0, repr(e))
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
  for n in compiles t1_rt; do add "$n" 0 5; done
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
