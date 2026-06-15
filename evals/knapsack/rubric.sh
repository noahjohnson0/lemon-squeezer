#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  # sanitize note: strip backslashes, turn double-quotes into single-quotes,
  # collapse tabs/newlines so the TSV record + final JSON stay valid.
  note="${note//\\/}"
  note="${note//\"/\'}"
  note="${note//$'\t'/ }"
  note="${note//$'\n'/ }"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/knapsack.py"
add "file:knapsack.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
else
  add "compiles" 0 5
fi

# Always run the behavioral block. The python heredoc NEVER aborts: on import
# failure it emits every check as a 0, and each case is individually guarded so
# one exception can never swallow the remaining checks. This keeps the
# denominator CONSTANT regardless of how broken the submission is.
RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>/dev/null
import sys

ok = True
try:
    from knapsack import solve
except Exception as e:
    print("IMPORT_ERR", repr(e)[:60], file=sys.stderr)
    ok = False

# explicit imports check, reflecting the import flag directly
print("imports", 1 if ok else 0)

def validate(items, cap, expected):
    """Return True iff solve(items,cap) returns a valid, optimal selection."""
    v, idxs = solve(items, cap)
    idxs = list(idxs)
    if not all(0 <= i < len(items) for i in idxs):
        return False, "bad idxs"
    if len(set(idxs)) != len(idxs):
        return False, "duplicate idxs"
    w = sum(items[i][0] for i in idxs)
    val = sum(items[i][1] for i in idxs)
    if w > cap:
        return False, "weight %d gt cap" % w
    if val != v:
        return False, "value mismatch %d vs %d" % (val, v)
    if v != expected:
        return False, "value %d ne expected %d" % (v, expected)
    return True, "ok"

cases = [
    # (items, capacity, expected_max_value)
    ([(2,3),(3,4),(4,5),(5,6)], 5, 7),       # take items 0+1: w=5, v=7
    ([(1,1),(2,2),(3,3),(4,4)], 5, 5),       # multiple options
    ([(10,60),(20,100),(30,120)], 50, 220),  # classic textbook
    ([(1,1)], 0, 0),                         # zero capacity
    ([], 10, 0),                             # empty
    ([(5,10)], 4, 0),                        # one too-heavy
    ([(5,10),(3,5),(2,3)], 5, 10),           # take just 0
]

def chk(name, fn):
    """ALWAYS prints one line so the denominator stays constant."""
    if not ok:
        print(name, 0, "no import")
        return
    try:
        passed, msg = fn()
        print(name, 1 if passed else 0, msg)
    except Exception as ex:
        print(name, 0, repr(ex)[:50])

for i, (items, cap, exp) in enumerate(cases, 1):
    # bind loop vars via default args so the lambda captures this iteration
    chk("k%d" % i, lambda it=items, c=cap, e=exp: validate(it, c, e))
PY
)
echo "$RES" >&2

# Declare every behavioral check name up front. We score each by looking up the
# line the python emitted; if a line is MISSING (e.g. python crashed entirely or
# was killed by gtimeout) the check is still added as 0 at its weight. This is
# what guarantees a constant denominator no matter what.
declare -a BEHAVIOR=(imports k1 k2 k3 k4 k5 k6 k7)
for name in "${BEHAVIOR[@]}"; do
  # weight: imports is worth 5, each behavioral case worth 9
  if [[ "$name" == "imports" ]]; then w=5; else w=9; fi
  line=$(printf '%s\n' "$RES" | awk -v n="$name" '$1==n {print; exit}')
  if [[ -z "$line" ]]; then
    add "$name" 0 "$w" "missing - no output"
  else
    pass=$(printf '%s' "$line" | awk '{print $2}')
    note=$(printf '%s' "$line" | cut -d' ' -f3-)
    add "$name" "$pass" "$w" "$note"
  fi
done

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
