#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/sat.py"
add "file:sat.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  RES=$(cd "$WS" && gtimeout 15 python3 - <<'PY' 2>&1
import sys
try: from sat import solve
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)

def verify(clauses, assignment):
    """True iff assignment satisfies every clause."""
    if assignment is None: return False
    for clause in clauses:
        if not any(((lit > 0 and assignment.get(abs(lit), False)) or
                    (lit < 0 and not assignment.get(abs(lit), False))) for lit in clause):
            return False
    return True

# (clauses, expected_sat: True/False)
CASES = [
    ([[1]], True),                                    # x1
    ([[1], [-1]], False),                             # x1 AND NOT x1
    ([[1, 2], [-1, 2]], True),                        # (x1 v x2) AND (-x1 v x2)  → x2=T
    ([[1, 2], [-1, -2], [-1, 2], [1, -2]], False),    # full XOR-like UNSAT
    ([[1, 2, 3], [-1, -2], [-2, -3], [-1, -3]], True),
    # 3-SAT, 5 vars, 8 clauses
    ([[1,2,3],[-1,2,3],[1,-2,3],[1,2,-3],[-1,-2,3],[-1,2,-3],[1,-2,-3],[-1,-2,-3]], False),  # all 8 disjunctions of 3 vars → UNSAT
    ([[1,-2],[2,-3],[3,-4],[4,-1]], True),            # implies chain — sat
]
for i,(cl, expected_sat) in enumerate(CASES,1):
    try:
        a = solve(cl)
        got_sat = a is not None
        if got_sat != expected_sat:
            print(f"c{i}", 0, f"got_sat={got_sat} want_sat={expected_sat}")
        elif expected_sat:
            ok = verify(cl, a)
            print(f"c{i}", 1 if ok else 0, f"assignment {'verifies' if ok else 'INVALID'}")
        else:
            print(f"c{i}", 1)
    except Exception as e:
        print(f"c{i}", 0, "ERR", repr(e))
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    add "$name" "$pass" 12 "$note"
  done < <(echo "$RES")
else
  for n in compiles c1; do add "$n" 0 5; done
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
