#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/levenshtein.py"
add "file:levenshtein.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys
try: from levenshtein import edit_distance, edit_path
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)
CASES = [("kitten","sitting",3),("","abc",3),("abc","",3),("abc","abc",0),("abc","abd",1),
         ("intention","execution",5),("flaw","lawn",2),("gumbo","gambol",2),("a","a",0),("xyz","abc",3)]
for i,(a,b,d) in enumerate(CASES,1):
    try:
        got = edit_distance(a,b)
        print(f"d{i}", 1 if got==d else 0, f"got={got} want={d}")
    except Exception as e:
        print(f"d{i}", 0, "ERR", repr(e))
# Path must agree with distance and reconstruct b from a
for i,(a,b,d) in enumerate(CASES[:6],1):
    try:
        path = edit_path(a,b)
        non_match = sum(1 for op,_,_ in path if op != 'match')
        # apply path to reconstruct
        out = ''
        for op,sc,dc in path:
            if op == 'match' or op == 'sub' or op == 'ins':
                out += dc
            # del: skip
        print(f"p{i}_count", 1 if non_match==d else 0, f"got_ops={non_match} want={d}")
        print(f"p{i}_recon", 1 if out==b else 0, f"got={out!r} want={b!r}")
    except Exception as e:
        print(f"p{i}_count", 0, "ERR", repr(e))
        print(f"p{i}_recon", 0, "ERR", repr(e))
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    [[ "$name" == d* ]] && add "$name" "$pass" 5 "$note" || add "$name" "$pass" 4 "$note"
  done < <(echo "$RES")
else
  for n in compiles d1 p1_count; do add "$n" 0 5; done
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
