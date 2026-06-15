#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
# sanitize: drop backslashes, turn double-quotes into single-quotes, collapse tabs/newlines
san() { printf '%s' "$1" | tr '\\"\t\n' "  '  " | tr -s ' '; }
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$(san "$note")")")
}

# --- The canonical, FIXED set of behavioral check names (constant denominator) ---
# Every one of these is ALWAYS emitted as pass=1 or pass=0, no matter how broken
# the submission is. The python block prints one line per name; if it crashes or
# never runs, the bash fallback fills the missing ones with 0.
BEHAV_NAMES=(imports c1 c2 c3 c4 c5 c6 c7)
BEHAV_W=11

T="$WS/sat.py"
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:sat.py" "$file_ok" 5

# compile check (0 if file missing)
comp=0
if [[ "$file_ok" == "1" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && comp=1
fi
add "compiles" "$comp" 5

# Run the behavioral cases. The python block ALWAYS prints exactly one line per
# BEHAV_NAMES entry ("name pass [note]"), even on import failure or exception.
RES=""
if [[ "$file_ok" == "1" ]]; then
  RES=$(cd "$WS" && gtimeout 15 python3 - <<'PY'
import sys

ok = True
solve = None
try:
    from sat import solve
except Exception as e:
    print("IMPORT_ERR", repr(e), file=sys.stderr)
    ok = False

def chk(name, fn):
    """Always print exactly one line: 'name pass [note]'. Never raise, never skip."""
    if not ok or solve is None:
        print(name, 0, "import failed")
        return
    try:
        passed, note = fn()
        print(name, 1 if passed else 0, note)
    except Exception as ex:
        print(name, 0, repr(ex)[:60])

# imports check reflects the import flag directly.
print("imports", 1 if (ok and solve is not None) else 0)

def verify(clauses, assignment):
    """True iff assignment satisfies every clause."""
    if assignment is None:
        return False
    for clause in clauses:
        if not any(((lit > 0 and assignment.get(abs(lit), False)) or
                    (lit < 0 and not assignment.get(abs(lit), False))) for lit in clause):
            return False
    return True

# (clauses, expected_sat: True/False)
CASES = [
    ([[1]], True),                                    # x1
    ([[1], [-1]], False),                             # x1 AND NOT x1
    ([[1, 2], [-1, 2]], True),                        # (x1 v x2) AND (-x1 v x2) -> x2=T
    ([[1, 2], [-1, -2], [-1, 2], [1, -2]], False),    # full XOR-like UNSAT
    ([[1, 2, 3], [-1, -2], [-2, -3], [-1, -3]], True),
    # all 8 disjunctions of 3 vars -> UNSAT
    ([[1,2,3],[-1,2,3],[1,-2,3],[1,2,-3],[-1,-2,3],[-1,2,-3],[1,-2,-3],[-1,-2,-3]], False),
    ([[1,-2],[2,-3],[3,-4],[4,-1]], True),            # implies chain - sat
]

def make_case(cl, expected_sat):
    def run():
        a = solve(cl)
        got_sat = a is not None
        if got_sat != expected_sat:
            return False, "got_sat=%s want_sat=%s" % (got_sat, expected_sat)
        if expected_sat:
            good = verify(cl, a)
            return good, ("assignment verifies" if good else "assignment INVALID")
        return True, "correctly UNSAT"
    return run

for i, (cl, expected_sat) in enumerate(CASES, 1):
    chk("c%d" % i, make_case(cl, expected_sat))
PY
)
fi

# Build a name->line map from whatever the python emitted.
declare -A EMITTED
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  nm=$(printf '%s' "$line" | awk '{print $1}')
  EMITTED["$nm"]="$line"
done <<<"$RES"

# Dump raw python output to stderr for debugging (NOT stdout).
printf '%s\n' "$RES" >&2

# Emit EVERY behavioral check at a fixed weight - constant denominator guaranteed.
# A missing line (python crashed before emitting it, or file missing) scores 0.
for nm in "${BEHAV_NAMES[@]}"; do
  if [[ -n "${EMITTED[$nm]:-}" ]]; then
    line="${EMITTED[$nm]}"
    pass=$(printf '%s' "$line" | awk '{print $2}')
    note=$(printf '%s' "$line" | cut -d' ' -f3-)
    add "$nm" "$pass" "$BEHAV_W" "$note"
  else
    add "$nm" 0 "$BEHAV_W" "no result emitted"
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
