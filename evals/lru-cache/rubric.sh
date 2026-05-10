#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/lru_cache.py"
add "file:lru_cache.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys
try: from lru_cache import LRUCache
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)
# Standard LeetCode trace
c = LRUCache(2)
c.put(1, 1); c.put(2, 2)
print("g1", 1 if c.get(1) == 1 else 0, c.get(1))
c.put(3, 3)  # evicts 2
print("g2", 1 if c.get(2) is None else 0, c.get(2))
c.put(4, 4)  # evicts 1
print("g3", 1 if c.get(1) is None else 0, c.get(1))
print("g4", 1 if c.get(3) == 3 else 0, c.get(3))
print("g5", 1 if c.get(4) == 4 else 0, c.get(4))
print("len", 1 if len(c) == 2 else 0, len(c))
# update marks recent
c2 = LRUCache(2)
c2.put('a', 1); c2.put('b', 2); c2.put('a', 3)  # a is now most recent
c2.put('c', 4)  # should evict b, not a
print("update_recent", 1 if c2.get('b') is None and c2.get('a') == 3 else 0)
# membership doesn't change order
c3 = LRUCache(2)
c3.put('x', 1); c3.put('y', 2)
print("contains", 1 if 'x' in c3 and 'y' in c3 else 0)
c3.put('z', 3)  # should evict x (LRU)
print("contains_no_touch", 1 if 'x' not in c3 and 'y' in c3 and 'z' in c3 else 0)
# capacity validation
try:
    LRUCache(0); print("invalid_cap", 0)
except ValueError: print("invalid_cap", 1)
except Exception as e: print("invalid_cap", 0, repr(e))
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    add "$name" "$pass" 7 "$note"
  done < <(echo "$RES")
else
  for n in compiles g1 update_recent invalid_cap; do add "$n" 0 5; done
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
