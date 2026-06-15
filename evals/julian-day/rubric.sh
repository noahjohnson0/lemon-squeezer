#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  # sanitize note: drop backslashes, turn double-quotes into single-quotes, strip tabs/newlines
  note="${note//\\/}"
  note="${note//\"/\'}"
  note="${note//$'\t'/ }"
  note="${note//$'\n'/ }"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/dates.py"
add "file:dates.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

# compiles check is independent of the python behavioral block
if [[ -f "$T" ]] && python3 -m py_compile "$T" 2>/dev/null; then
  add "compiles" 1 5
else
  add "compiles" 0 5
fi

# Behavioral block. Emits EXACTLY one "<name> <pass> [note]" line per declared
# check, ALWAYS, regardless of import errors or per-case exceptions. The set of
# names is fixed below, so the denominator is constant no matter how broken the
# submission is. Import failure forces every behavioral check (and the explicit
# "imports" check) to 0 without aborting.
RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>>/dev/null
import sys

ok = True
easter = None
julian_day = None
try:
    from dates import easter, julian_day
except Exception as e:
    print("IMPORT_ERR", repr(e)[:80], file=sys.stderr)
    ok = False

def sanitize(s):
    return str(s).replace("\\", "").replace('"', "'").replace("\t", " ").replace("\n", " ")[:60]

def chk(name, fn):
    if not ok:
        print(name, 0, "import_failed")
        return
    try:
        passed, note = fn()
        print(name, 1 if passed else 0, sanitize(note))
    except Exception as ex:
        print(name, 0, sanitize("ERR " + repr(ex)))

# explicit imports check, reflects the import flag directly
print("imports", 1 if ok else 0, "ok" if ok else "names not importable")

EASTER = [(1900,(1900,4,15)), (1961,(1961,4,2)), (2000,(2000,4,23)), (2024,(2024,3,31)),
          (2025,(2025,4,20)), (2026,(2026,4,5)), (2038,(2038,4,25))]

def make_easter_case(y, exp):
    def f():
        got = easter(y)
        got = tuple(got) if isinstance(got, (list, tuple)) else None
        return (got == exp), "got=%s want=%s" % (got, exp)
    return f

for y, exp in EASTER:
    chk("e_%d" % y, make_easter_case(y, exp))

# Pre-1583 must raise ValueError
def pre1583():
    raised = None
    try:
        easter(1500)
        return False, "no raise"
    except ValueError:
        return True, "raised ValueError"
    except Exception as ex:
        return False, "wrong exc " + repr(ex)
chk("e_pre1583", pre1583)

JD = [((2000,1,1,12.0), 2451545.0), ((1858,11,17,0.0), 2400000.5),
      ((1900,1,1,0.0), 2415020.5), ((2026,5,10,0.0), 2461170.5)]

def make_jd_case(args, exp):
    def f():
        got = julian_day(*args)
        return (abs(got - exp) < 1e-3), "got=%s want=%s" % (got, exp)
    return f

for args, exp in JD:
    chk("jd_%d_%d_%d" % (args[0], args[1], args[2]), make_jd_case(args, exp))
PY
)
rc=$?
echo "$RES" >&2

# Fixed list of behavioral check names, in emit order. We add each at its weight
# whether or not python managed to emit it, so the denominator is CONSTANT.
declare -a BNAMES=(imports
  e_1900 e_1961 e_2000 e_2024 e_2025 e_2026 e_2038 e_pre1583
  jd_2000_1_1 jd_1858_11_17 jd_1900_1_1 jd_2026_5_10)

# Parse emitted lines into name -> "pass note" so we can look them up by name.
declare -A PASS NOTE
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  n=$(printf '%s' "$line" | awk '{print $1}')
  p=$(printf '%s' "$line" | awk '{print $2}')
  rest=$(printf '%s' "$line" | cut -d' ' -f3-)
  [[ "$n" == "IMPORT_ERR" ]] && continue
  PASS["$n"]="$p"
  NOTE["$n"]="$rest"
done < <(printf '%s\n' "$RES")

# Emit every declared behavioral check exactly once. Missing/garbled -> 0.
for n in "${BNAMES[@]}"; do
  p="${PASS[$n]:-0}"
  [[ "$p" != "1" ]] && p=0
  note="${NOTE[$n]:-missing}"
  add "$n" "$p" 7 "$note"
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
