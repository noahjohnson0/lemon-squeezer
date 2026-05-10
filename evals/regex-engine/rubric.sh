#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/re_match.py"
add "file:re_match.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  if grep -qE "^\s*import\s+re\b|from\s+re\s+import" "$T"; then
    add "no_stdlib_re" 0 10 "imports re module"
  else
    add "no_stdlib_re" 1 10
  fi
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys
try: from re_match import fullmatch
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)
CASES = [
    # (pattern, text, expected)
    ("abc", "abc", True),
    ("abc", "ab", False),
    ("abc", "abcd", False),
    ("a.c", "abc", True),
    ("a.c", "axc", True),
    ("a.c", "ac", False),
    ("a*", "", True),
    ("a*", "aaaa", True),
    ("a*b", "b", True),
    ("a*b", "aab", True),
    ("a+b", "b", False),
    ("a+b", "ab", True),
    ("a?b", "b", True),
    ("a?b", "ab", True),
    ("a?b", "aab", False),
    (r"\d+", "12345", True),
    (r"\d+", "12a45", False),
    (r"[a-z]+", "hello", True),
    (r"[a-z]+", "Hello", False),
    (r"[^0-9]+", "abc", True),
    (r"\w+", "hello_123", True),
    (r"\w+", "hello world", False),
    (r"\s+", "   ", True),
    ("a.*z", "abcz", True),
    ("a.*z", "az", True),
    ("a.*z", "a", False),
]
for i,(p,t,e) in enumerate(CASES,1):
    try:
        got = fullmatch(p, t)
        print(f"r{i}", 1 if got == e else 0, f"p={p!r} t={t!r} got={got} want={e}")
    except Exception as ex:
        print(f"r{i}", 0, "ERR", repr(ex))
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    add "$name" "$pass" 3 "$note"
  done < <(echo "$RES")
else
  for n in compiles r1; do add "$n" 0 5; done
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
