#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/mywc.py"
add "file:mywc.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 10 || add "compiles" 0 10

  # --help works
  HELP="$(cd "$WS" && gtimeout 5 python3 mywc.py --help 2>&1 || true)"
  [[ -n "$HELP" ]] && add "help:exits_with_output" 1 5 || add "help:exits_with_output" 0 5
  echo "$HELP" | grep -qiE "usage|usage:|mywc" && add "help:has_usage" 1 5 || add "help:has_usage" 0 5

  # Real run: write a known sample, verify exact output
  SAMPLE="$WS/__sample.txt"
  printf 'hello world foo\nbar baz qux\nthe quick brown fox\n' > "$SAMPLE"
  # Expected: 3 lines, 10 words, 48 chars
  EXPECTED="3 10 48 __sample.txt"
  OUT="$(cd "$WS" && gtimeout 5 python3 mywc.py __sample.txt 2>/dev/null | tr -s ' ' || true)"
  rm -f "$SAMPLE"
  [[ "$(echo "$OUT" | tr -s ' ')" == "$EXPECTED" ]] && add "output:exact_format" 1 25 "got: '$OUT'" || add "output:exact_format" 0 25 "expected '$EXPECTED' got '$OUT'"

  # Missing file -> non-zero exit
  cd "$WS" && gtimeout 5 python3 mywc.py /nonexistent_xyz_123 >/dev/null 2>&1
  rc=$?
  [[ $rc -ne 0 ]] && add "error:nonzero_on_missing" 1 5 || add "error:nonzero_on_missing" 0 5
else
  for n in compiles help:exits_with_output help:has_usage output:exact_format error:nonzero_on_missing; do
    add "$n" 0 5
  done
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
