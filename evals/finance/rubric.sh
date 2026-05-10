#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/finance.py"
add "file:finance.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5

  RES=$(cd "$WS" && gtimeout 15 python3 - <<'PY' 2>&1
import sys
try:
    from finance import mortgage_payment, amortization_table, npv, irr
except Exception as e:
    print("IMPORT_ERR", e); sys.exit(1)

def near(a, b, tol):
    try: return abs(float(a) - float(b)) < tol
    except: return False

# Mortgage payment
print("mp_300k_6_30",   1 if near(mortgage_payment(300000, 0.06, 30), 1798.65, 0.05) else 0,
      "got", round(mortgage_payment(300000, 0.06, 30), 4))
print("mp_500k_4p5_15", 1 if near(mortgage_payment(500000, 0.045, 15), 3824.97, 0.10) else 0,
      "got", round(mortgage_payment(500000, 0.045, 15), 4))
print("mp_100k_5_30",   1 if near(mortgage_payment(100000, 0.05, 30), 536.82, 0.05) else 0,
      "got", round(mortgage_payment(100000, 0.05, 30), 4))

# Amortization
try:
    table = amortization_table(100000, 0.05, 30)
    ok_len  = (len(table) == 360)
    row1 = table[0]; rowL = table[-1]
    ok_r1p = near(row1.get("payment"),  536.82, 0.05)
    ok_r1i = near(row1.get("interest"), 416.6667, 0.10)
    ok_r1pr= near(row1.get("principal"), 120.15, 0.10)
    ok_final_zero = near(rowL.get("balance"), 0.0, 0.05)
    print("amort_len",          1 if ok_len  else 0, "got", len(table))
    print("amort_row1_payment", 1 if ok_r1p  else 0, "got", row1.get("payment"))
    print("amort_row1_interest",1 if ok_r1i  else 0, "got", row1.get("interest"))
    print("amort_row1_principal",1 if ok_r1pr else 0, "got", row1.get("principal"))
    print("amort_final_zero",   1 if ok_final_zero else 0, "got", rowL.get("balance"))
except Exception as e:
    for n in ["amort_len","amort_row1_payment","amort_row1_interest","amort_row1_principal","amort_final_zero"]:
        print(n, 0, "ERR", e)

# NPV
print("npv_basic",  1 if near(npv(0.10, [-1000, 200, 300, 400, 500]), 71.78, 0.5) else 0,
      "got", round(npv(0.10, [-1000, 200, 300, 400, 500]), 4))
print("npv_zero",   1 if near(npv(0.0,  [-100, 50, 50]), 0.0, 0.01) else 0,
      "got", round(npv(0.0, [-100, 50, 50]), 4))

# IRR
try: r = irr([-1000, 200, 300, 400, 500])
except Exception as e: r = None
print("irr_basic", 1 if (r is not None and near(r, 0.1280, 0.01)) else 0, "got", r)

try: r2 = irr([-100, 110])
except Exception: r2 = None
print("irr_simple", 1 if (r2 is not None and near(r2, 0.10, 0.001)) else 0, "got", r2)
PY
)
  echo "$RES" >&2

  weight_for() { case "$1" in
    mp_*)                    echo 5;;
    amort_len)               echo 5;;
    amort_row1_payment)      echo 6;;
    amort_row1_interest)     echo 6;;
    amort_row1_principal)    echo 6;;
    amort_final_zero)        echo 8;;
    npv_basic)               echo 8;;
    npv_zero)                echo 4;;
    irr_basic)               echo 12;;
    irr_simple)              echo 5;;
    *)                       echo 3;;
  esac; }

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    add "$name" "$pass" "$(weight_for "$name")" "$note"
  done < <(echo "$RES")
else
  for n in compiles mp_300k_6_30 amort_final_zero npv_basic irr_basic; do add "$n" 0 5; done
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
