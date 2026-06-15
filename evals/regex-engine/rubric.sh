#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  # sanitize note: strip backslashes and replace double-quotes so the JSON stays valid
  note="${note//\\/}"
  note="${note//\"/\'}"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/re_match.py"

# --- static checks (always emitted) ---
# Weights are deliberately small: an empty stub that merely exists, compiles,
# and trivially "doesn't import re" must NOT be able to clear a passing score
# on static credit alone. Real points live in the behavioral cases below.
if [[ -f "$T" ]]; then
  add "file:re_match.py" 1 2
else
  add "file:re_match.py" 0 2
fi

if [[ -f "$T" ]] && python3 -m py_compile "$T" 2>/dev/null; then
  add "compiles" 1 3
else
  add "compiles" 0 3
fi

if [[ -f "$T" ]] && grep -qE "^\s*import\s+re\b|from\s+re\s+import" "$T"; then
  add "no_stdlib_re" 0 5 "imports re module"
else
  add "no_stdlib_re" 1 5
fi

# --- behavioral checks (ALWAYS emitted, one line per declared case) ---
# The python block never aborts: on import error it sets a flag and every chk()
# still prints "<name> 0", so the denominator is constant regardless of how
# broken the submission is. The first emitted line is the "imports" check.
RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys

ok = True
try:
    from re_match import fullmatch
except Exception as e:
    print("IMPORT_ERR", repr(e)[:80], file=sys.stderr)
    ok = False

def chk(name, fn):
    if not ok:
        print(name, 0, "no_import")
        return
    try:
        print(name, 1 if fn() else 0)
    except Exception as ex:
        print(name, 0, repr(ex)[:50])

# explicit import gate (also reflected as a weighted check in bash)
print("imports", 1 if ok else 0)

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
for i, (p, t, e) in enumerate(CASES, 1):
    chk("r%d" % i, (lambda p=p, t=t, e=e: fullmatch(p, t) == e))
PY
)
rc=$?
echo "$RES" >&2

# Build a name->line map so we can score declared checks even if a case crashed
# the interpreter mid-stream (the trailing declared checks default to 0).
declare -A SEEN
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "$line" == IMPORT_ERR* ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  SEEN["$name"]="$pass	$note"
done < <(printf '%s\n' "$RES")

emit() {
  local name="$1" weight="$2"
  if [[ -n "${SEEN[$name]+x}" ]]; then
    local pass note
    IFS=$'\t' read -r pass note <<<"${SEEN[$name]}"
    add "$name" "$pass" "$weight" "$note"
  else
    add "$name" 0 "$weight" "not emitted"
  fi
}

# imports gate (weighted) + every behavioral case at the same weight.
# Declaring them here (not from the python output) guarantees a CONSTANT
# denominator: missing/crashed cases are added as 0 instead of vanishing.
# NOTE: keep NCASES in sync with the CASES list in the python block above.
NCASES=26
emit "imports" 10
for i in $(seq 1 "$NCASES"); do
  emit "r$i" 3
done

# --- emit final JSON (stdout) ; everything else above went to stderr ---
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
