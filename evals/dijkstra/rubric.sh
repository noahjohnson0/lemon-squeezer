#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  # sanitize note: strip backslashes, replace double-quotes with single,
  # collapse tabs/newlines so the JSON below never breaks.
  note="${note//\\/}"
  note="${note//\"/\'}"
  note="${note//$'\t'/ }"
  note="${note//$'\n'/ }"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/dijkstra.py"

# --- static checks (always emitted) ---------------------------------------
have_file=0; [[ -f "$T" ]] && have_file=1
add "file:dijkstra.py" "$have_file" 5

compiles=0
if [[ "$have_file" == "1" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && compiles=1
fi
add "compiles" "$compiles" 5

# heapq usage (cheap static signal, never aborts)
heapq=0
[[ "$have_file" == "1" ]] && grep -q 'heapq' "$T" 2>/dev/null && heapq=1
add "uses_heapq" "$heapq" 4

# --- behavioral checks ----------------------------------------------------
# The python block ALWAYS prints exactly one "name pass [note]" line per
# declared check via chk(). On import error (or any per-case exception) the
# corresponding check prints pass=0 instead of vanishing, so the set of
# emitted check names - and therefore the denominator - is CONSTANT.
declare -a BEHAV=(imports g1_dist g1_path self nopath tie_dist tie_path_valid big_dist big_path)
declare -A SCORE
for n in "${BEHAV[@]}"; do SCORE["$n"]=0; done
declare -A NOTE
for n in "${BEHAV[@]}"; do NOTE["$n"]=""; done

RES=""
if [[ "$have_file" == "1" ]]; then
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>/dev/null
import sys

ok = True
try:
    from dijkstra import shortest_path
except Exception as e:
    print("IMPORT_ERR", repr(e), file=sys.stderr)
    ok = False

def chk(name, fn):
    if not ok:
        print(name, 0, "import_failed")
        return
    try:
        print(name, 1 if fn() else 0)
    except Exception as ex:
        print(name, 0, repr(ex)[:60])

# importable at all?
print("imports", 1 if ok else 0)

# Graph 1: classic - A->B->C->D = 1+2+1 = 4 (vs A->C->D = 4+1 = 5)
g1 = {"A":[("B",1),("C",4)], "B":[("C",2),("D",5)], "C":[("D",1)], "D":[]}
chk("g1_dist",  lambda: shortest_path(g1, "A", "D")[0] == 4)
chk("g1_path",  lambda: shortest_path(g1, "A", "D")[1] == ["A","B","C","D"])
# Source == dest
chk("self",     lambda: shortest_path(g1, "A", "A")[0] == 0 and shortest_path(g1, "A", "A")[1] == ["A"])
# No path
g2 = {"A":[("B",1)], "B":[], "C":[]}
chk("nopath",   lambda: shortest_path(g2, "A", "C") == (float('inf'), []))
# Tie-breaker (any valid shortest path acceptable)
g3 = {"A":[("B",1),("C",1)], "B":[("D",1)], "C":[("D",1)], "D":[]}
chk("tie_dist", lambda: shortest_path(g3, "A", "D")[0] == 2)
chk("tie_path_valid", lambda: shortest_path(g3, "A", "D")[1] in (["A","B","D"], ["A","C","D"]))
# Larger graph - a->b->c->d->e = 2+1+1+2 = 6
g4 = {"a":[("b",2),("c",5)], "b":[("c",1),("d",4)], "c":[("d",1)], "d":[("e",2)], "e":[]}
chk("big_dist", lambda: shortest_path(g4, "a", "e")[0] == 6)
chk("big_path", lambda: shortest_path(g4, "a", "e")[1] == ["a","b","c","d","e"])
PY
)
fi
echo "$RES" >&2

# Parse whatever the python emitted; default-0 entries already seeded above.
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  [[ "$name" == "IMPORT_ERR" ]] && continue
  if [[ -n "${SCORE[$name]+x}" ]]; then
    SCORE["$name"]="$pass"
    NOTE["$name"]="$note"
  fi
done < <(printf '%s\n' "$RES")

# Emit every behavioral check at a fixed weight, ALWAYS.
add "imports" "${SCORE[imports]}" 6 "${NOTE[imports]}"
for n in g1_dist g1_path self nopath tie_dist tie_path_valid big_dist big_path; do
  add "$n" "${SCORE[$n]}" 8 "${NOTE[$n]}"
done

# --- emit JSON (the ONLY thing on stdout) ---------------------------------
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
