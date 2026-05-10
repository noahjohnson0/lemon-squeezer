#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/balance.py"
add "file:balance.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5

  # Run a battery of equations — each worth 10 pts
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys
try:
    from balance import balance
except Exception as e:
    print("IMPORT_ERR", e); sys.exit(1)

# Each entry: (input, expected_lhs, expected_rhs)
cases = [
    ("H2 + O2 -> H2O",                         [2,1],     [2]),
    ("CH4 + O2 -> CO2 + H2O",                  [1,2],     [1,2]),
    ("C2H6 + O2 -> CO2 + H2O",                 [2,7],     [4,6]),
    ("Fe + Cl2 -> FeCl3",                      [2,3],     [2]),
    ("Al + HCl -> AlCl3 + H2",                 [2,6],     [2,3]),
    ("Al2(SO4)3 + NaOH -> Al(OH)3 + Na2SO4",   [1,6],     [2,3]),
    ("KMnO4 + HCl -> KCl + MnCl2 + H2O + Cl2", [2,16],    [2,2,8,5]),
]

ok = 0
for eq, el, er in cases:
    try:
        lhs, rhs = balance(eq)
        # Allow tuple or list
        lhs = list(lhs); rhs = list(rhs)
        if lhs == el and rhs == er:
            print("PASS", eq); ok += 1
        else:
            print("FAIL", eq, "got", lhs, rhs, "want", el, er)
    except Exception as e:
        print("ERR", eq, repr(e))
print("---", ok, "/", len(cases))
PY
)
  echo "$RES" | tail -20 >&2
  for eq_idx in 1 2 3 4 5 6 7; do
    eq_line=$(echo "$RES" | sed -n "${eq_idx}p")
    if echo "$eq_line" | grep -q "^PASS"; then
      add "case:eq${eq_idx}" 1 10
    else
      add "case:eq${eq_idx}" 0 10 "$eq_line"
    fi
  done

  # Bonus: raises ValueError for unbalanceable
  ERR_OUT=$(cd "$WS" && gtimeout 5 python3 -c "
from balance import balance
try:
    balance('Na -> Cl')
    print('NO_RAISE')
except ValueError:
    print('VALUEERROR')
except Exception as e:
    print('OTHER', type(e).__name__)
" 2>&1)
  if [[ "$ERR_OUT" == "VALUEERROR" ]]; then
    add "raises_valueerror" 1 5
  else
    add "raises_valueerror" 0 5 "$ERR_OUT"
  fi
else
  add "compiles" 0 5
  for i in 1 2 3 4 5 6 7; do add "case:eq${i}" 0 10; done
  add "raises_valueerror" 0 5
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
