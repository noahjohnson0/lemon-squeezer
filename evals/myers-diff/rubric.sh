#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
declare -A seen

# Sanitize notes so the emitted JSON stays valid: drop backslashes and turn
# double-quotes into single-quotes (both break the hand-rolled JSON below).
sanitize() {
  local s="$1"
  s="${s//\\/}"
  s="${s//\"/\'}"
  s="${s//$'\n'/ }"
  s="${s//$'\t'/ }"
  printf '%s' "$s"
}
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  note="$(sanitize "$note")"
  seen["$n"]=1
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

# Portable timeout: prefer gtimeout (macOS coreutils), fall back to timeout.
TO="$(command -v gtimeout || command -v timeout)"

# ---------------------------------------------------------------------------
# Declared check inventory. EVERY name here is ALWAYS scored exactly once, so
# the denominator (sum of weights) is constant no matter how broken the
# submission is. Behavioral checks are emitted by the python probe; anything
# the probe fails to emit is filled in as a 0 by the safety net below.
# ---------------------------------------------------------------------------
# weight 5  (cheap / happy path)
LIGHT=(imports rt_basic rt_empty_both rt_empty_a rt_empty_b eq_identical eq_all_ins eq_all_del)
# weight 10 (correctness on edge cases)
MED=(rt_interleaved rt_dups rt_transpose rt_single rt_prefix_suffix tags_valid recon_a recon_b)
# weight 16 (the hard, discriminating checks: minimality + perf)
HARD=(min_interleaved min_dups min_transpose min_alt min_buried lcs_is_lcs min_count_exact perf_2k)

T="$WS/mydiff.py"
add "file:mydiff.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
else
  add "compiles" 0 5
fi

# Static anti-cheat: must not lean on difflib (the task is to implement it).
# Only meaningful when there is a real file; gated below on import success too.
DIFFLIB_HIT=0
if [[ -f "$T" ]]; then
  grep -qE '(^|[^_a-zA-Z])difflib([^_a-zA-Z]|$)|import[[:space:]]+difflib|from[[:space:]]+difflib' "$T" && DIFFLIB_HIT=1
fi

# ---------------------------------------------------------------------------
# Behavioral probe. The python block NEVER exits early and NEVER lets one
# failing case abort the rest: chk() always prints exactly one line per check,
# and an "imports" line is always emitted. Everything is deterministic: inputs
# are fixed, perf uses a fixed-size synthetic input, no randomness/clock/net.
# ---------------------------------------------------------------------------
RES=$(cd "$WS" && "$TO" 15 python3 - <<'PY' 2>/tmp/mydiff_pyerr_$$
import sys, time

ok = True
try:
    from mydiff import diff, apply
except Exception as e:
    print("imports", 0, "import failed:", repr(e)[:60])
    ok = False
else:
    print("imports", 1)

def emit(name, passed, note=""):
    note = str(note).replace("\\", "").replace('"', "'").replace("\n", " ").replace("\t", " ")
    print(name, 1 if passed else 0, note)

def chk(name, fn):
    if not ok:
        emit(name, 0, "no import")
        return
    try:
        emit(name, 1 if fn() else 0)
    except Exception as ex:
        emit(name, 0, "ERR " + repr(ex)[:50])

# ---- independent gold LCS (so the grader never trusts the submission) ----
def lcs_len(a, b):
    n, m = len(a), len(b)
    prev = [0] * (m + 1)
    for i in range(n - 1, -1, -1):
        cur = [0] * (m + 1)
        ai = a[i]
        for j in range(m - 1, -1, -1):
            if ai == b[j]:
                cur[j] = prev[j + 1] + 1
            else:
                cur[j] = prev[j] if prev[j] >= cur[j + 1] else cur[j + 1]
        prev = cur
    return prev[0]

def is_subsequence(sub, seq):
    it = iter(seq)
    return all(any(x == y for y in it) for x in sub)

def tags_ok(script):
    for t in script:
        if not (isinstance(t, (tuple, list)) and len(t) == 2):
            return False
        if t[0] not in ('=', '-', '+'):
            return False
    return True

def roundtrip(a, b):
    return list(apply(a, diff(a, b))) == list(b)

def recon_side(a, b, keep):
    # keep = ('=','-') reproduces a ; keep = ('=','+') reproduces b
    script = diff(a, b)
    out = [ln for tag, ln in script if tag in keep]
    return out

def min_ok(a, b):
    # number of '-'/'+' tuples must equal len(a)+len(b)-2*LCS
    script = diff(a, b)
    if not roundtrip(a, b):
        return False
    edits = sum(1 for tag, _ in script if tag in ('-', '+'))
    return edits == len(a) + len(b) - 2 * lcs_len(a, b)

def eq_count(a, b):
    return sum(1 for tag, _ in diff(a, b) if tag == '=')

# ---- fixtures -----------------------------------------------------------
ID = ["l%d" % i for i in range(20)]
A_INS = []
B_INS = ["x", "y", "z"]
INTER_A = ["a", "b", "c", "d", "e", "f"]
INTER_B = ["a", "X", "c", "Y", "e", "Z"]          # every other line changed
DUP_A = ["a", "b", "a", "b", "a"]
DUP_B = ["b", "a", "b", "a", "b"]
TR_A = ["1", "2", "3", "4", "5", "6"]
TR_B = ["4", "5", "6", "1", "2", "3"]             # block transposition
BIG = ["line%04d" % i for i in range(400)]
SINGLE_A = list(BIG)
SINGLE_B = list(BIG); SINGLE_B[200] = "CHANGED"   # one line changed in big file
PS_A = ["h1", "h2"] + ["m%d" % i for i in range(10)] + ["t1", "t2"]
PS_B = ["h1", "h2"] + ["n%d" % i for i in range(8)] + ["t1", "t2"]
# buried: small edit between two large unchanged blocks that ALSO share lines
BUR_A = ["p%d" % i for i in range(50)] + ["x", "y", "z"] + ["q%d" % i for i in range(50)]
BUR_B = ["p%d" % i for i in range(50)] + ["x", "Y", "z"] + ["q%d" % i for i in range(50)]

# ---- round-trip / equality (cheap) --------------------------------------
chk("rt_basic",        lambda: roundtrip(["a", "b", "c"], ["a", "c", "d"]))
chk("rt_empty_both",   lambda: roundtrip([], []))
chk("rt_empty_a",      lambda: roundtrip([], B_INS))
chk("rt_empty_b",      lambda: roundtrip(["p", "q"], []))
chk("eq_identical",    lambda: [t for t, _ in diff(ID, ID)] == ['='] * len(ID))
chk("eq_all_ins",      lambda: [t for t, _ in diff([], B_INS)] == ['+'] * len(B_INS) and roundtrip([], B_INS))
chk("eq_all_del",      lambda: [t for t, _ in diff(["p", "q"], [])] == ['-'] * 2 and roundtrip(["p", "q"], []))

# ---- structural correctness (medium) ------------------------------------
chk("rt_interleaved",  lambda: roundtrip(INTER_A, INTER_B))
chk("rt_dups",         lambda: roundtrip(DUP_A, DUP_B))
chk("rt_transpose",    lambda: roundtrip(TR_A, TR_B))
chk("rt_single",       lambda: roundtrip(SINGLE_A, SINGLE_B))
chk("rt_prefix_suffix",lambda: roundtrip(PS_A, PS_B))
chk("tags_valid",      lambda: tags_ok(diff(INTER_A, INTER_B)) and tags_ok(diff(DUP_A, DUP_B)))
chk("recon_a",         lambda: recon_side(INTER_A, INTER_B, ('=', '-')) == INTER_A
                              and recon_side(DUP_A, DUP_B, ('=', '-')) == DUP_A)
chk("recon_b",         lambda: recon_side(INTER_A, INTER_B, ('=', '+')) == INTER_B
                              and recon_side(DUP_A, DUP_B, ('=', '+')) == DUP_B)

# ---- minimality (hard, heavy weight) ------------------------------------
chk("min_interleaved", lambda: min_ok(INTER_A, INTER_B))
chk("min_dups",        lambda: min_ok(DUP_A, DUP_B))
chk("min_transpose",   lambda: min_ok(TR_A, TR_B))
chk("min_alt",         lambda: min_ok(["a", "b", "c", "d", "e", "f", "g"],
                                      ["a", "1", "c", "2", "e", "3", "g"]))
chk("min_buried",      lambda: min_ok(BUR_A, BUR_B))
# '=' lines must be a common subsequence AND of LCS length (i.e. truly the LCS)
chk("lcs_is_lcs",      lambda: (lambda s: (s == lcs_len(INTER_A, INTER_B)
                                           and is_subsequence([ln for tag, ln in diff(INTER_A, INTER_B) if tag == '='], INTER_A)
                                           and is_subsequence([ln for tag, ln in diff(INTER_A, INTER_B) if tag == '='], INTER_B)))(eq_count(INTER_A, INTER_B)))
# exact minimal edit count across a battery of adversarial cases
def min_count_exact():
    cases = [(INTER_A, INTER_B), (DUP_A, DUP_B), (TR_A, TR_B),
             (SINGLE_A, SINGLE_B), (PS_A, PS_B), (BUR_A, BUR_B),
             (["x"] * 5, ["x"] * 3), (["a", "b"], ["b", "a"])]
    return all(min_ok(a, b) for a, b in cases)
chk("min_count_exact", min_count_exact)

# ---- performance: ~2000 vs ~2000 lines with a long common subsequence ----
def perf_2k():
    base = ["row %06d content here" % i for i in range(2000)]
    a = list(base)
    b = list(base)
    # mutate ~5% of lines so there is real diff work but a long LCS remains;
    # a correct O(n*m) DP / Myers finishes in well under a second, an
    # exponential / unmemoized-recursive solution times out.
    for i in range(0, 2000, 20):
        b[i] = "MUT %06d" % i
    t0 = time.perf_counter()
    script = diff(a, b)
    dt = time.perf_counter() - t0
    if list(apply(a, script)) != b:
        return False
    edits = sum(1 for tag, _ in script if tag in ('-', '+'))
    if edits != len(a) + len(b) - 2 * lcs_len(a, b):
        return False
    return dt < 6.0
chk("perf_2k", perf_2k)
PY
)
PYRC=$?
PYERR="$(cat /tmp/mydiff_pyerr_$$ 2>/dev/null)"; rm -f /tmp/mydiff_pyerr_$$
{ echo "=== python stdout ==="; echo "$RES"; echo "=== python stderr ==="; echo "$PYERR"; echo "=== python rc=$PYRC ==="; } >&2

# Derive import success from the emitted "imports" line.
IMPORTS_PASS=0
IMPORTS_NOTE="python probe did not emit imports line"

declare -A WEIGHT_OF
for n in "${LIGHT[@]}"; do WEIGHT_OF["$n"]=5; done
for n in "${MED[@]}";   do WEIGHT_OF["$n"]=10; done
for n in "${HARD[@]}";  do WEIGHT_OF["$n"]=16; done

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  if [[ "$name" == "imports" ]]; then
    IMPORTS_PASS="$pass"; IMPORTS_NOTE="$note"; continue
  fi
  w="${WEIGHT_OF[$name]:-}"
  [[ -z "$w" ]] && continue   # ignore anything unexpected
  add "$name" "$pass" "$w" "$note"
done < <(printf '%s\n' "$RES")

# Explicit imports check so a non-importing file is penalized directly.
add "imports" "$IMPORTS_PASS" 5 "$IMPORTS_NOTE"

# Static anti-cheat scored as its own check: only credit "didn't use difflib"
# when there is an importable solution, so a trivial/empty stub can't farm the
# absence of difflib for free.
if [[ "$IMPORTS_PASS" == "1" ]]; then
  if [[ "$DIFFLIB_HIT" == "1" ]]; then
    add "no_difflib" 0 10 "uses difflib"
  else
    add "no_difflib" 1 10
  fi
else
  add "no_difflib" 0 10 "no importable solution"
fi

# Safety net: any declared behavioral check the probe failed to emit (python
# crashed, timed out, or was killed) is scored 0 at its declared weight. This
# guarantees the denominator stays constant even with zero probe output.
for n in "${LIGHT[@]}"; do
  [[ "$n" == "imports" ]] && continue
  [[ -n "${seen[$n]:-}" ]] || add "$n" 0 5 "missing from probe output"
done
for n in "${MED[@]}"; do
  [[ -n "${seen[$n]:-}" ]] || add "$n" 0 10 "missing from probe output"
done
for n in "${HARD[@]}"; do
  [[ -n "${seen[$n]:-}" ]] || add "$n" 0 16 "missing from probe output"
done

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
