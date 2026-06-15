#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
# Sanitize notes so the emitted JSON stays valid: drop backslashes and turn
# double-quotes into single-quotes (both break the hand-rolled JSON below).
sanitize() {
  local s="$1"
  s="${s//\/}"
  s="${s//\"/\'}"
  s="${s//$'\n'/ }"
  s="${s//$'\t'/ }"
  printf '%s' "$s"
}
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  note="$(sanitize "$note")"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/matops.py"
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:matops.py" "$file_ok" 5

# compile check (0 if file missing)
compile_ok=0
if [[ "$file_ok" == "1" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && compile_ok=1
fi
add "compiles" "$compile_ok" 5

# Behavioral checks. The python heredoc ALWAYS prints exactly one line per
# declared check whether the import works or not, so the denominator is
# constant for every submission (empty stub, import-error, partial, correct).
RES=$(WS="$WS" python3 - <<'PY' 2>&1
import sys, os
ws = os.environ["WS"]
sys.path.insert(0, ws)

ok = True
try:
    from matops import determinant, inverse, matmul
except Exception as e:
    print("IMPORT_ERR", repr(e)[:80], file=sys.stderr)
    ok = False

def emit(name, passed, note=""):
    note = str(note).replace("\\", "").replace('"', "'").replace("\n", " ").replace("\t", " ")
    print(name, 1 if passed else 0, note)

def chk(name, fn):
    if not ok:
        emit(name, 0, "import failed")
        return
    try:
        emit(name, 1 if fn() else 0)
    except Exception as ex:
        emit(name, 0, repr(ex)[:50])

# Import status as its own behavioral check; a non-importing file is penalized
# directly here and every dependent check below scores 0 (never skipped).
emit("imports", ok, "" if ok else "could not import determinant/inverse/matmul")

def near(a, b, tol=1e-6):
    return abs(a - b) < tol

def near_mat(A, B, tol=1e-4):
    if len(A) != len(B):
        return False
    for i in range(len(A)):
        if len(A[i]) != len(B[i]):
            return False
        for j in range(len(A[i])):
            if not near(A[i][j], B[i][j], tol):
                return False
    return True

# determinant cases
chk("det_2x2",  lambda: near(determinant([[1,2],[3,4]]), -2))
chk("det_3x3",  lambda: near(determinant([[6,1,1],[4,-2,5],[2,8,7]]), -306))
chk("det_id",   lambda: near(determinant([[1,0,0],[0,1,0],[0,0,1]]), 1))
chk("det_zero", lambda: near(determinant([[1,2,3],[2,4,6],[7,8,9]]), 0, 1e-6))

# inverse cases
chk("inv_2x2",  lambda: near_mat(inverse([[4,7],[2,6]]), [[0.6,-0.7],[-0.2,0.4]]))
chk("inv_id",   lambda: near_mat(inverse([[1,0,0],[0,1,0],[0,0,1]]), [[1,0,0],[0,1,0],[0,0,1]]))

def singular_raises():
    try:
        inverse([[1,2],[2,4]])
    except ValueError:
        return True
    return False
chk("inv_singular", singular_raises)

# matmul
chk("matmul", lambda: matmul([[1,2],[3,4]], [[5,6],[7,8]]) == [[19,22],[43,50]])

# round trip: A @ inv(A) == I
def round_trip():
    A2 = [[3,1,2],[1,4,1],[2,1,5]]
    prod = matmul(A2, inverse(A2))
    I = [[1.0 if i == j else 0.0 for j in range(3)] for i in range(3)]
    return near_mat(prod, I, 1e-4)
chk("inv_round_trip", round_trip)
PY
)
echo "$RES" >&2

# Derive import success from the emitted "imports" line so the static
# anti-cheat check can be gated on a real, importable solution (an empty
# stub must not earn credit for "not misusing numpy.linalg").
import_ok=0
if printf '%s\n' "$RES" | grep -qE '^imports[[:space:]]+1'; then
  import_ok=1
fi

# Static anti-cheat: must implement elimination by hand, not call numpy.linalg.
# Only credited when the file both exists and actually imports - otherwise a
# trivial file would game this absence-check for free.
if [[ "$import_ok" == "1" && "$file_ok" == "1" ]]; then
  if grep -qE "from[[:space:]]+numpy\.linalg[[:space:]]+import|np\.linalg\.|numpy\.linalg" "$T"; then
    add "no_numpy_linalg" 0 10 "uses numpy.linalg"
  else
    add "no_numpy_linalg" 1 10
  fi
else
  add "no_numpy_linalg" 0 10 "no importable solution"
fi

# Fold each emitted behavioral line in at a uniform weight. Because the python
# always prints every declared check, the denominator never changes.
declare -A SEEN
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  [[ "$name" == "IMPORT_ERR" ]] && continue
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  add "$name" "$pass" 8 "$note"
  SEEN["$name"]=1
done < <(printf '%s\n' "$RES")

# Safety net: if the python crashed catastrophically (e.g. interpreter missing)
# so a declared behavioral check never printed, add it as a 0 so the
# denominator stays constant no matter what.
for n in imports det_2x2 det_3x3 det_id det_zero inv_2x2 inv_id inv_singular matmul inv_round_trip; do
  [[ -z "${SEEN[$n]:-}" ]] && add "$n" 0 8 "no output from rubric"
done

total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in "${checks[@]+"${checks[@]}"}"; do
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
