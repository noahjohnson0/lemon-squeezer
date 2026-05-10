#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/pwstrength.py"
add "file:pwstrength.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5

  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys
try:
    from pwstrength import score
except Exception as e:
    print("IMPORT_ERR", e); sys.exit(1)

# (input, expected_min_score, expected_max_score, must_contain_reason_substr_or_None)
cases = [
    ("",                  0, 0, "too-short"),
    ("short",             0, 0, "too-short"),
    ("password",          0, 0, "blocklist"),
    ("PASSWORD",          0, 0, "blocklist"),
    ("123456",            0, 0, None),
    ("alllowercase1",     1, 2, None),
    ("Tr0ub4dor",         1, 2, None),
    ("CorrectHorse9!",    3, 3, None),
    ("Tr0ub4dor!",        2, 3, None),
    ("aaaa1234",          0, 1, None),
    ("12345678",          0, 0, "blocklist"),
    ("Mxk7@Lp9zQ#1Vw3R",  4, 4, None),
    ("MyPassword12345!",  2, 3, "sequence"),
]

for pw, lo, hi, must in cases:
    try:
        s, reasons = score(pw)
        ok_score = (lo <= s <= hi)
        ok_reason = (must is None) or any(must in r for r in reasons)
        status = "PASS" if (ok_score and ok_reason) else "FAIL"
        print(status, repr(pw), "score=" + str(s), "reasons=" + ",".join(reasons), "want", lo, hi, "must=" + str(must))
    except Exception as e:
        print("ERR", repr(pw), repr(e))
PY
)
  echo "$RES" >&2
  # Score by counting PASS lines per case; each case 7 pts
  i=0
  while IFS= read -r line; do
    i=$((i+1))
    [[ -z "$line" ]] && continue
    if echo "$line" | grep -q "^PASS"; then
      add "case:${i}" 1 7
    else
      add "case:${i}" 0 7 "$line"
    fi
  done < <(echo "$RES")
else
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13; do add "case:${i}" 0 7; done
  add "compiles" 0 5
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
