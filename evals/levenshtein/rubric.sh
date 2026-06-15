#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
declare -A seen
sanitize() {
  # strip backslashes and convert double-quotes to single quotes so notes
  # never corrupt the emitted JSON (see CLAUDE.md rubric gotcha #2)
  local s="$1"
  s="${s//\\/}"
  s="${s//\"/\'}"
  printf '%s' "$s"
}
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  note="$(sanitize "$note")"
  seen["$n"]=1
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

# ---------------------------------------------------------------------------
# Declared check inventory. EVERY name here is ALWAYS scored exactly once, so
# the denominator (sum of weights) is constant regardless of how broken the
# submission is. Behavioral checks (d*, p*) are emitted by the python block;
# anything the python block fails to emit is filled in as a 0 by the safety
# net below. This is the core invariant: missing checks must never vanish.
# ---------------------------------------------------------------------------
DIST_CHECKS=(d1 d2 d3 d4 d5 d6 d7 d8 d9 d10)
PATH_CHECKS=(p1_count p1_recon p2_count p2_recon p3_count p3_recon \
             p4_count p4_recon p5_count p5_recon p6_count p6_recon)

T="$WS/levenshtein.py"
add "file:levenshtein.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
else
  add "compiles" 0 5
fi

# Run the behavioral probe. The python block NEVER exits early and NEVER lets
# one failing case abort the rest: chk() always prints a line, and an "imports"
# line is always emitted reflecting whether the required API was importable.
RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>/tmp/lev_pyerr_$$
import sys
ok = True
try:
    from levenshtein import edit_distance, edit_path
except Exception as e:
    print("imports", 0, "import failed:", repr(e)[:60])
    ok = False
else:
    print("imports", 1)

def chk(name, fn):
    if not ok:
        print(name, 0, "no import")
        return
    try:
        print(name, 1 if fn() else 0)
    except Exception as ex:
        print(name, 0, "ERR", repr(ex)[:50])

CASES = [("kitten","sitting",3),("","abc",3),("abc","",3),("abc","abc",0),("abc","abd",1),
         ("intention","execution",5),("flaw","lawn",2),("gumbo","gambol",2),("a","a",0),("xyz","abc",3)]

for i,(a,b,d) in enumerate(CASES,1):
    chk(f"d{i}", (lambda a=a,b=b,d=d: edit_distance(a,b)==d))

def path_count_ok(a,b,d):
    path = edit_path(a,b)
    non_match = sum(1 for op,_,_ in path if op != 'match')
    return non_match == d

def path_recon_ok(a,b):
    path = edit_path(a,b)
    out = ''
    for op,sc,dc in path:
        if op in ('match','sub','ins'):
            out += dc
        # 'del' contributes nothing
    return out == b

for i,(a,b,d) in enumerate(CASES[:6],1):
    chk(f"p{i}_count", (lambda a=a,b=b,d=d: path_count_ok(a,b,d)))
    chk(f"p{i}_recon", (lambda a=a,b=b: path_recon_ok(a,b)))
PY
)
PYRC=$?
PYERR="$(cat /tmp/lev_pyerr_$$ 2>/dev/null)"; rm -f /tmp/lev_pyerr_$$
{ echo "=== python stdout ==="; echo "$RES"; echo "=== python stderr ==="; echo "$PYERR"; echo "=== python rc=$PYRC ==="; } >&2

# Default the import flag to failure; the python block overrides it if it ran.
IMPORTS_PASS=0
IMPORTS_NOTE="python probe did not emit imports line"

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  case "$name" in
    imports)
      IMPORTS_PASS="$pass"; IMPORTS_NOTE="$note" ;;
    d*)
      add "$name" "$pass" 5 "$note" ;;
    p*_count|p*_recon)
      add "$name" "$pass" 4 "$note" ;;
    *)
      : ;;  # ignore anything unexpected
  esac
done < <(printf '%s\n' "$RES")

# Explicit imports check so a non-importing file is penalized directly.
add "imports" "$IMPORTS_PASS" 5 "$IMPORTS_NOTE"

# Safety net: any declared behavioral check the python block failed to emit
# (e.g. python crashed, timed out, or was killed) is scored 0. This guarantees
# the denominator stays constant even when the probe produces no output at all.
for n in "${DIST_CHECKS[@]}"; do
  [[ -n "${seen[$n]:-}" ]] || add "$n" 0 5 "missing from probe output"
done
for n in "${PATH_CHECKS[@]}"; do
  [[ -n "${seen[$n]:-}" ]] || add "$n" 0 4 "missing from probe output"
done

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
