#!/usr/bin/env bash
# Score a bug-fix workspace.
set -u
WS="${1:?workspace dir required}"
[[ -d "$WS" ]] || { echo "{\"error\":\"workspace not found\"}"; exit 1; }

declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/csv_total.py"
add "file:csv_total.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 10 || add "compiles" 0 10

  # Run it on data.csv with a 5s timeout
  if [[ -f "$WS/data.csv" ]]; then
    OUT="$(cd "$WS" && gtimeout 5 python3 csv_total.py data.csv 2>/dev/null || true)"
    [[ "$OUT" == "100" ]] && add "outputs:100" 1 30 "expected exactly 100" || add "outputs:100" 0 30 "got: '$OUT'"
  else
    add "outputs:100" 0 30 "no data.csv"
  fi

  # Bonus: check it doesn't just print 100 by hardcoding
  if [[ "${OUT:-}" == "100" ]]; then
    # Modify the data file: drop the 40 line, expected sum becomes 60
    TMPDIR="$(mktemp -d)"
    cp "$T" "$TMPDIR/csv_total.py"
    cat > "$TMPDIR/data.csv" <<EOF
name,amount
alpha,5
beta,15
gamma,wat
delta,25
EOF
    OUT2="$(cd "$TMPDIR" && gtimeout 5 python3 csv_total.py data.csv 2>/dev/null || true)"
    rm -rf "$TMPDIR"
    [[ "$OUT2" == "45" ]] && add "generalizes" 1 10 "passes second hidden case" || add "generalizes" 0 10 "second case got: '$OUT2', expected 45"
  else
    add "generalizes" 0 10
  fi
else
  add "compiles" 0 10
  add "outputs:100" 0 30
  add "generalizes" 0 10
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
