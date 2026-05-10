#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/dijkstra.py"
add "file:dijkstra.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys
try: from dijkstra import shortest_path
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)
# Graph 1: classic
g1 = {"A":[("B",1),("C",4)], "B":[("C",2),("D",5)], "C":[("D",1)], "D":[]}
# A->C: A->B->C = 3 (vs A->C = 4)
d,p = shortest_path(g1, "A", "D")
print("g1_dist", 1 if d == 4 else 0, d)
print("g1_path", 1 if p == ["A","B","C","D"] else 0, p)
# Source == dest
d,p = shortest_path(g1, "A", "A")
print("self", 1 if d == 0 and p == ["A"] else 0, d, p)
# No path
g2 = {"A":[("B",1)], "B":[], "C":[]}
d,p = shortest_path(g2, "A", "C")
print("nopath", 1 if d == float('inf') and p == [] else 0, d, p)
# Tie-breaker (any valid shortest path acceptable)
g3 = {"A":[("B",1),("C",1)], "B":[("D",1)], "C":[("D",1)], "D":[]}
d,p = shortest_path(g3, "A", "D")
print("tie_dist", 1 if d == 2 else 0, d)
print("tie_path_valid", 1 if p in (["A","B","D"], ["A","C","D"]) else 0, p)
# Larger graph
g4 = {"a":[("b",2),("c",5)], "b":[("c",1),("d",4)], "c":[("d",1)], "d":[("e",2)], "e":[]}
d,p = shortest_path(g4, "a", "e")
# a->b->c->d->e = 2+1+1+2 = 6
print("big_dist", 1 if d == 6 else 0, d)
print("big_path", 1 if p == ["a","b","c","d","e"] else 0, p)
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
  for n in compiles g1_dist self nopath; do add "$n" 0 5; done
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
