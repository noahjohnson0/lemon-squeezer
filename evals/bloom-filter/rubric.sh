#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
# add NAME PASS WEIGHT [NOTE]
# Sanitizes NOTE so it can never break the emitted JSON (strip backslashes,
# replace double-quotes with single, collapse to one line).
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  note="${note//\\//}"     # backslash -> forward slash (kills \x.. escapes)
  note="${note//\"/\'}"    # double quote -> single quote
  note="${note//$'\t'/ }"  # tabs would corrupt our field separator
  note="${note//$'\n'/ }"  # newlines too
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/bloom.py"
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:bloom.py" "$file_ok" 5

compile_ok=0
if [[ "$file_ok" == "1" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && compile_ok=1
fi
add "compiles" "$compile_ok" 5

# Behavioral probe. The python ALWAYS prints exactly one line per declared
# check (chk() never aborts the rest, never sys.exit's). The very first
# token of each line is the check name; second token is 1/0; remainder is a
# free-form note. An "imports" line reflects whether the API imported at all.
# Everything here is informational on stderr EXCEPT the per-check lines, which
# we capture and turn into scored checks below. No JSON is produced here.
RES=$(cd "$WS" && gtimeout 20 python3 - <<'PY' 2>/dev/null
import sys, random

ok = True
try:
    from bloom import BloomFilter
except Exception as e:
    sys.stderr.write("IMPORT_ERR %r\n" % (e,))
    ok = False

def chk(name, fn):
    # ALWAYS prints exactly one line: name pass [note]. Never raises out.
    if not ok:
        print(name, 0, "no_import")
        return
    try:
        pass_ = 1 if fn() else 0
        print(name, pass_)
    except Exception as ex:
        note = repr(ex)[:60].replace("\\", "/").replace('"', "'").replace("\n", " ")
        print(name, 0, note)

print("imports", 1 if ok else 0)

random.seed(42)

def t_no_false_neg():
    b = BloomFilter(1000, 0.01)
    items = [f"key_{i}" for i in range(500)]
    for x in items:
        b.add(x)
    miss = sum(1 for x in items if x not in b)
    return miss == 0

def t_low_false_pos():
    b = BloomFilter(1000, 0.01)
    for i in range(500):
        b.add(f"key_{i}")
    absent = [f"other_{i}" for i in range(2000)]
    present = sum(1 for x in absent if x in b)
    fpr = present / len(absent)
    sys.stderr.write("observed_fpr=%.3f\n" % fpr)
    return fpr < 0.05

def t_len_tracks():
    b2 = BloomFilter(100, 0.01)
    b2.add("a"); b2.add("b"); b2.add("c")
    n = len(b2)
    sys.stderr.write("len=%r\n" % (n,))
    return 2 <= n <= 4  # allow approximate

def t_multi_type():
    b3 = BloomFilter(100, 0.01)
    b3.add(42); b3.add("hello"); b3.add(b"\x00\x01")
    return (42 in b3) and ("hello" in b3) and (b"\x00\x01" in b3)

def t_empty_clean():
    b4 = BloomFilter(100, 0.01)
    empty_present = sum(1 for x in [f"x_{i}" for i in range(100)] if x in b4)
    sys.stderr.write("empty_present=%r\n" % (empty_present,))
    return empty_present == 0

chk("no_false_neg", t_no_false_neg)
chk("low_false_pos", t_low_false_pos)
chk("len_tracks", t_len_tracks)
chk("multi_type", t_multi_type)
chk("empty_clean", t_empty_clean)
PY
)
probe_rc=$?
echo "$RES" >&2
[[ $probe_rc -ne 0 ]] && echo "PROBE_RC=$probe_rc (timeout/crash -> missing lines default to 0)" >&2

# Pull the value of a single named check out of $RES (second whitespace token),
# defaulting to 0 if the line is absent (e.g. timeout killed python early).
val_of() {
  local key="$1" line
  line=$(echo "$RES" | awk -v k="$key" '$1==k {print $2; exit}')
  [[ "$line" == "1" ]] && echo 1 || echo 0
}
note_of() {
  local key="$1"
  echo "$RES" | awk -v k="$key" '$1==k {$1="";$2="";sub(/^ +/,"");print;exit}'
}

# Declare EVERY behavioral check unconditionally with a fixed weight. Because
# val_of defaults to 0 for any line the probe failed to emit, the denominator
# is constant (always these weights) regardless of how broken the submission
# is. The "imports" check directly penalizes a non-importing file.
add "imports"       "$(val_of imports)"       10 "$(note_of imports)"
add "no_false_neg"  "$(val_of no_false_neg)"  25 "$(note_of no_false_neg)"
add "low_false_pos" "$(val_of low_false_pos)" 15 "$(note_of low_false_pos)"
add "len_tracks"    "$(val_of len_tracks)"    10 "$(note_of len_tracks)"
add "multi_type"    "$(val_of multi_type)"    10 "$(note_of multi_type)"
add "empty_clean"   "$(val_of empty_clean)"   10 "$(note_of empty_clean)"

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
