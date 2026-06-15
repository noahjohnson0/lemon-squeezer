#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  # sanitize note: strip backslashes and replace double-quotes with single
  # quotes so the emitted JSON never breaks (see CLAUDE.md rubric gotcha #2).
  note="${note//\\/ }"
  note="${note//\"/\'}"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

# Number of behavioral cases the python block ALWAYS emits. Kept in sync with
# the `cases` list below so the denominator is constant no matter what the
# submission does (missing file, import error, crash mid-case, partial, full).
NCASES=13

T="$WS/pwstrength.py"
if [[ -f "$T" ]]; then add "file:pwstrength.py" 1 5; else add "file:pwstrength.py" 0 5; fi

if [[ -f "$T" ]]; then
  if python3 -m py_compile "$T" 2>/dev/null; then add "compiles" 1 5; else add "compiles" 0 5; fi
else
  add "compiles" 0 5
fi

# Always run the python harness when the file exists. It NEVER aborts: every
# declared check (imports + each case) is printed exactly once as "name 1|0".
# When the file is missing we synthesize the same set of lines, all failing,
# so the denominator stays identical.
if [[ -f "$T" ]]; then
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>>/dev/null
import sys

ok = True
score = None
try:
    from pwstrength import score
except Exception as e:
    print("IMPORT_ERR", repr(e)[:80], file=sys.stderr)
    ok = False

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

def sanitize(s):
    # keep notes single-line and JSON-safe; add() also sanitizes but be tidy.
    return str(s).replace("\\", " ").replace('"', "'").replace("\n", " ").replace("\t", " ")[:80]

def emit(name, passed, note=""):
    # ALWAYS print one line per check. Never raise out of here.
    print(name, 1 if passed else 0, sanitize(note))

# explicit imports check so a non-importing file is penalized directly.
emit("imports", ok, "" if ok else "import failed")

for idx, (pw, lo, hi, must) in enumerate(cases, start=1):
    name = "case:%d" % idx
    if not ok:
        emit(name, False, "no import")
        continue
    try:
        s, reasons = score(pw)
        ok_score = (lo <= s <= hi)
        ok_reason = (must is None) or any(must in r for r in reasons)
        passed = bool(ok_score and ok_reason)
        note = "" if passed else ("score=%s reasons=%s want %s-%s must=%s"
                                  % (s, ",".join(map(str, reasons)), lo, hi, must))
        emit(name, passed, note)
    except Exception as ex:
        emit(name, False, "EXC " + sanitize(repr(ex)))
PY
)
  echo "$RES" >&2

  imports_seen=0
  declare -A seen_case
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # split: first token name, second token pass, rest is note
    name="${line%% *}"
    rest="${line#* }"
    pass="${rest%% *}"
    note="${rest#* }"
    [[ "$note" == "$rest" ]] && note=""   # no note present
    case "$name" in
      imports)
        imports_seen=1
        if [[ "$pass" == "1" ]]; then add "imports" 1 6; else add "imports" 0 6 "$note"; fi
        ;;
      case:*)
        seen_case["$name"]=1
        if [[ "$pass" == "1" ]]; then add "$name" 1 7; else add "$name" 0 7 "$note"; fi
        ;;
    esac
  done < <(echo "$RES")

  # Defensively guarantee a constant denominator: if the python harness died
  # before emitting some line (timeout, hard crash, OOM), backfill the missing
  # checks as failures so the total never shrinks below the file-missing path.
  [[ "$imports_seen" != "1" ]] && add "imports" 0 6 "no imports line"
  for i in $(seq 1 "$NCASES"); do
    if [[ -z "${seen_case[case:$i]:-}" ]]; then
      add "case:$i" 0 7 "missing line"
    fi
  done
else
  # File missing: emit the SAME set of checks, all failing, so the denominator
  # is identical to the present-file path.
  add "imports" 0 6 "no file"
  for i in $(seq 1 "$NCASES"); do add "case:$i" 0 7 "no file"; done
fi

# emit (final JSON to stdout; everything else above went to stderr)
total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in ${checks[@]+"${checks[@]}"}; do
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
