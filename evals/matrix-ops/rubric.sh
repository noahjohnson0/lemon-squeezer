#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/matops.py"
add "file:matops.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  if grep -qE "from\s+numpy\.linalg\s+import|np\.linalg\.|numpy\.linalg" "$T"; then
    add "no_numpy_linalg" 0 10 "uses numpy.linalg"
  else
    add "no_numpy_linalg" 1 10
  fi
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys
try: from matops import determinant, inverse, matmul
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)
def near(a, b, tol=1e-6): return abs(a - b) < tol
def near_mat(A, B, tol=1e-4):
    return all(near(A[i][j], B[i][j], tol) for i in range(len(A)) for j in range(len(A[0])))
# det cases
print("det_2x2",  1 if near(determinant([[1,2],[3,4]]),     -2) else 0, determinant([[1,2],[3,4]]))
print("det_3x3",  1 if near(determinant([[6,1,1],[4,-2,5],[2,8,7]]), -306) else 0)
print("det_id",   1 if near(determinant([[1,0,0],[0,1,0],[0,0,1]]),    1) else 0)
print("det_zero", 1 if near(determinant([[1,2,3],[2,4,6],[7,8,9]]),    0, 1e-6) else 0)
# inverse cases
A = [[4,7],[2,6]]
Ai = [[0.6,-0.7],[-0.2,0.4]]
try:
    inv = inverse(A)
    print("inv_2x2", 1 if near_mat(inv, Ai) else 0, inv)
except Exception as e: print("inv_2x2", 0, repr(e))
# inverse identity
try:
    inv = inverse([[1,0,0],[0,1,0],[0,0,1]])
    print("inv_id", 1 if near_mat(inv, [[1,0,0],[0,1,0],[0,0,1]]) else 0)
except Exception as e: print("inv_id", 0, repr(e))
# singular raises
try:
    inverse([[1,2],[2,4]]); print("inv_singular", 0, "no raise")
except ValueError: print("inv_singular", 1)
except Exception as e: print("inv_singular", 0, repr(e))
# matmul
print("matmul",       1 if matmul([[1,2],[3,4]], [[5,6],[7,8]]) == [[19,22],[43,50]] else 0)
# A * inv(A) = I
import math
A2 = [[3,1,2],[1,4,1],[2,1,5]]
try:
    inv = inverse(A2)
    prod = matmul(A2, inv)
    I = [[1.0 if i==j else 0.0 for j in range(3)] for i in range(3)]
    print("inv_round_trip", 1 if near_mat(prod, I, 1e-4) else 0)
except Exception as e: print("inv_round_trip", 0, repr(e))
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
  for n in compiles det_2x2 inv_2x2; do add "$n" 0 5; done
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
