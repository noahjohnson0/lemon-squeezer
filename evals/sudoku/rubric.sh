#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/sudoku.py"
add "file:sudoku.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5

  RES=$(cd "$WS" && gtimeout 60 python3 - <<'PY' 2>&1
import sys
try:
    from sudoku import solve
except Exception as e:
    print("IMPORT_ERR", e); sys.exit(1)

# Each puzzle as a string of 81 chars (0 or .)
PUZZLES = {
    # Easy
    "easy": "530070000600195000098000060800060003400803001700020006060000280000419005000080079",
    # Medium
    "med":  "100920000524010000000000070050008102000000000402700090060000000000030945000071006",
    # Hard (requires backtracking)
    "hard": "000000907000420180000705026100904000050000040000507009920108000034059000507000000",
    # Expert (the "World's hardest sudoku" by Arto Inkala — slow w/o good heuristics, allow 30s timeout)
    "expert":"800000000003600000070090200050007000000045700000100030001000068008500010090000400",
    # Empty cell pattern test
    "min":  "000000000000003085001020000000507000004000100090000000500000073002010000000040009",
}

def to_board(s):
    out = []
    for r in range(9):
        out.append([int(c) if c.isdigit() else 0 for c in s[r*9:(r+1)*9]])
    return out

def is_valid(b):
    if len(b) != 9: return False
    if any(len(r) != 9 for r in b): return False
    if any(c < 1 or c > 9 for r in b for c in r): return False
    for i in range(9):
        if sorted(b[i]) != list(range(1,10)): return False
        if sorted(b[r][i] for r in range(9)) != list(range(1,10)): return False
    for br in range(0,9,3):
        for bc in range(0,9,3):
            if sorted(b[br+r][bc+c] for r in range(3) for c in range(3)) != list(range(1,10)): return False
    return True

def matches_clues(orig, b):
    for r in range(9):
        for c in range(9):
            if orig[r][c] != 0 and b[r][c] != orig[r][c]: return False
    return True

for name, s in PUZZLES.items():
    orig = to_board(s)
    try:
        out = solve([row[:] for row in orig])
        ok_valid   = is_valid(out)
        ok_clues   = matches_clues(orig, out)
        ok_unmuted = (orig == to_board(s))  # input not mutated by solver
        print(name, 1 if (ok_valid and ok_clues and ok_unmuted) else 0,
              "valid="+str(ok_valid), "clues="+str(ok_clues), "input_intact="+str(ok_unmuted))
    except Exception as e:
        print(name, 0, "ERR", repr(e))
PY
)
  echo "$RES" >&2

  for puzzle in easy med hard expert min; do
    line=$(echo "$RES" | grep "^$puzzle " | head -1)
    pass=$(echo "$line" | awk '{print $2}')
    case "$puzzle" in
      easy)   w=10 ;;
      med)    w=14 ;;
      hard)   w=20 ;;
      expert) w=20 ;;
      min)    w=16 ;;
    esac
    [[ "$pass" == "1" ]] && add "puzzle:$puzzle" 1 "$w" || add "puzzle:$puzzle" 0 "$w" "$line"
  done

  # Bonus: must not import third-party (z3, etc) — pure python expected
  if grep -qE "^\s*import\s+(z3|constraint)" "$T"; then
    add "no_third_party_solver" 0 5 "third-party solver used"
  else
    add "no_third_party_solver" 1 5
  fi
else
  for n in compiles puzzle:easy puzzle:med puzzle:hard puzzle:expert puzzle:min no_third_party_solver; do add "$n" 0 5; done
fi

# emit
total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in "${checks[@]}"; do
    IFS=$'\t' read -r name pass weight note <<<"$c"
    total=$((total+weight))
    [[ "$pass" == "1" ]] && gained=$((gained+weight))
    [[ $first -eq 0 ]] && printf ',\n'
    printf '    {"name":"%s","pass":%s,"weight":%s,"note":"%s"}' "$name" "$pass" "$weight" "$note"
    first=0
  done
  printf '\n  ],\n'
  pct=0
  [[ $total -gt 0 ]] && pct=$(( (gained * 100) / total ))
  printf '  "gained": %s,\n  "total": %s,\n  "score_pct": %s\n}\n' "$gained" "$total" "$pct"
}
