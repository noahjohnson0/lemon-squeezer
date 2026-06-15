#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks

# add NAME PASS WEIGHT [NOTE]
# Sanitizes NOTE so it can never break the emitted JSON (strip backslashes,
# replace double-quotes, collapse tabs/newlines). The emitted JSON is the ONLY
# thing on stdout; every diagnostic goes to stderr.
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  note="${note//\\//}"     # backslash -> forward slash (kills \x.. escapes)
  note="${note//\"/\'}"    # double quote -> single quote
  note="${note//$'\t'/ }"  # tabs would corrupt our field separator
  note="${note//$'\n'/ }"  # newlines too
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

# Portable timeout: prefer gtimeout (mac/coreutils), fall back to timeout (linux
# / msys). If neither exists, TO is empty and we run python directly.
TO="$(command -v gtimeout || command -v timeout || true)"
run_to() {  # run_to SECONDS -- cmd...
  local secs="$1"; shift
  if [[ -n "$TO" ]]; then "$TO" "$secs" "$@"; else "$@"; fi
}

T="$WS/intervals.py"
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:intervals.py" "$file_ok" 4

compile_ok=0
if [[ "$file_ok" == "1" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && compile_ok=1
fi
add "compiles" "$compile_ok" 4

# ----------------------------------------------------------------------------
# Behavioral probe. The python ALWAYS prints exactly one line per declared
# check (chk() never aborts the rest, never sys.exit's; import failure makes
# every check print 0). The first token is the check name, the second is 1/0,
# the rest is a free-form note. Wrapped in a portable timeout so even a fully
# hung submission cannot block the rubric -- missing lines default to 0 below.
# No JSON is produced here; all of this is captured into $RES.
# ----------------------------------------------------------------------------
RES=$(cd "$WS" && run_to 25 python3 - <<'PY' 2>/dev/null
import sys, time, copy

ok = True
try:
    from intervals import merge, insert, intersect
except Exception as e:
    sys.stderr.write("IMPORT_ERR %r\n" % (e,))
    ok = False

def emit(name, passed, note=""):
    note = str(note).replace("\\", "/").replace('"', "'").replace("\n", " ").replace("\t", " ")
    print(name, 1 if passed else 0, note)

def chk(name, fn):
    # ALWAYS prints exactly one line. import-broken => 0. exception => 0.
    if not ok:
        emit(name, 0, "no_import")
        return
    try:
        emit(name, 1 if fn() else 0)
    except Exception as ex:
        emit(name, 0, repr(ex)[:60])

emit("imports", 1 if ok else 0, "" if ok else "could not import merge/insert/intersect")

def eq(a, b):
    # compare as lists of [start,end] pairs (tolerate tuples)
    if a is None or b is None:
        return a is b
    if len(a) != len(b):
        return False
    return all(list(x) == list(y) for x, y in zip(a, b))

# ---------------- merge: happy path (a NAIVE solution should pass these) ----
chk("merge_overlap",   lambda: eq(merge([[1,3],[2,6],[8,10],[15,18]]), [[1,6],[8,10],[15,18]]))
chk("merge_unsorted",  lambda: eq(merge([[8,10],[1,3],[15,18],[2,6]]), [[1,6],[8,10],[15,18]]))
chk("merge_single",    lambda: eq(merge([[5,7]]), [[5,7]]))

# ---------------- merge: HARD edge cases -----------------------------------
# touching at a shared endpoint must merge
chk("merge_touch_endpoint", lambda: eq(merge([[1,3],[3,5]]), [[1,5]]))
# integer-adjacent (gap of exactly 1) must merge
chk("merge_int_adjacent",   lambda: eq(merge([[1,2],[3,4]]), [[1,4]]))
# a genuine gap of 2 must NOT merge
chk("merge_real_gap",       lambda: eq(merge([[1,2],[4,5]]), [[1,2],[4,5]]))
# full containment collapses
chk("merge_containment",    lambda: eq(merge([[1,10],[3,4],[2,5]]), [[1,10]]))
# duplicates collapse to one
chk("merge_duplicates",     lambda: eq(merge([[1,4],[1,4],[1,4]]), [[1,4]]))
# empty input -> empty list
chk("merge_empty",          lambda: eq(merge([]), []))
# negatives + chained adjacency across many: [-5,-3],[-2,0],[1,1] -> [-5,1]
chk("merge_negative_chain", lambda: eq(merge([[1,1],[-2,0],[-5,-3]]), [[-5,1]]))
# raises on inverted interval
def merge_validates():
    try:
        merge([[1,3],[7,2]])
        return False
    except ValueError:
        return True
chk("merge_validates", merge_validates)
# must NOT mutate the caller's input list or inner pairs
def merge_no_mutate():
    src = [[3,5],[1,2]]
    snap = copy.deepcopy(src)
    merge(src)
    return src == snap
chk("merge_no_mutate", merge_no_mutate)

# ---------------- insert ----------------------------------------------------
chk("insert_basic",    lambda: eq(insert([[1,3],[7,9]], [2,5]), [[1,5],[7,9]]))
chk("insert_empty",    lambda: eq(insert([], [2,5]), [[2,5]]))
# new bridges two existing intervals (overlap on both sides)
chk("insert_bridge",   lambda: eq(insert([[1,2],[6,7],[10,12]], [3,8]), [[1,8],[10,12]]))
# integer-adjacency on insert: inserting [4,5] next to [1,3] and [6,9] -> [1,9]
chk("insert_adjacent", lambda: eq(insert([[1,3],[6,9]], [4,5]), [[1,9]]))
# insert that touches nothing lands sorted in the gap
chk("insert_gap",      lambda: eq(insert([[1,2],[10,11]], [5,6]), [[1,2],[5,6],[10,11]]))
# insert before everything
chk("insert_front",    lambda: eq(insert([[5,6],[8,9]], [1,2]), [[1,2],[5,6],[8,9]]))
def insert_no_mutate():
    src = [[1,2],[10,11]]
    snap = copy.deepcopy(src)
    insert(src, [5,6])
    return src == snap
chk("insert_no_mutate", insert_no_mutate)

# ---------------- intersect -------------------------------------------------
chk("isect_basic",   lambda: eq(intersect([[0,2],[5,10],[13,23],[24,25]],
                                           [[1,5],[8,12],[15,24],[25,26]]),
                                 [[1,2],[5,5],[8,10],[15,23],[24,24],[25,25]]))
chk("isect_empty_a", lambda: eq(intersect([], [[1,5]]), []))
chk("isect_empty_b", lambda: eq(intersect([[1,5]], []), []))
# single shared point counts as an intersection
chk("isect_touch",   lambda: eq(intersect([[1,3]], [[3,5]]), [[3,3]]))
# disjoint -> empty
chk("isect_disjoint",lambda: eq(intersect([[1,2],[7,8]], [[3,4],[9,10]]), []))
# one interval covering many small ones in the other list
chk("isect_nested",  lambda: eq(intersect([[1,20]], [[2,3],[5,8],[14,19]]),
                                 [[2,3],[5,8],[14,19]]))
PY
)
probe_rc=$?
echo "$RES" >&2
[[ $probe_rc -ne 0 ]] && echo "PROBE_RC=$probe_rc (correctness probe timeout/crash -> missing lines default to 0)" >&2

# ----------------------------------------------------------------------------
# PERFORMANCE probe (SEPARATE process so a quadratic blow-up here cannot wipe
# out the correctness credit above). Deterministic, no randomness: we build
# large sorted/disjoint inputs and time the ops IN-PROCESS against a generous
# wall budget. A correct O(n log n)/O(n) solution finishes in well under the
# budget; an O(n^2) solution either exceeds the in-process budget (prints 0) or
# is killed by the outer portable timeout (line absent -> defaults to 0 below).
# Either way a quadratic loses every perf point. The budget (6s) is comfortably
# above a correct solution's runtime (<<1s) and far below a 100k quadratic's,
# so the verdict is machine-independent.
# ----------------------------------------------------------------------------
PERF=$(cd "$WS" && run_to 30 python3 - <<'PY' 2>/dev/null
import sys, time

ok = True
try:
    from intervals import merge, insert, intersect
except Exception as e:
    sys.stderr.write("PERF_IMPORT_ERR %r\n" % (e,))
    ok = False

BUDGET = 6.0
N = 100000

def emit(name, passed, note=""):
    note = str(note).replace("\\", "/").replace('"', "'").replace("\n", " ").replace("\t", " ")
    print(name, 1 if passed else 0, note)

def eq(a, b):
    if a is None or b is None:
        return a is b
    if len(a) != len(b):
        return False
    return all(list(x) == list(y) for x, y in zip(a, b))

def timed(name, build, run, verify):
    if not ok:
        emit(name, 0, "no_import")
        return
    try:
        data = build()
        t0 = time.perf_counter()
        out = run(data)
        dt = time.perf_counter() - t0
        good = verify(out)
        sys.stderr.write("%s dt=%.3fs ok=%s budget=%.1f\n" % (name, dt, good, BUDGET))
        emit(name, good and dt < BUDGET, "dt=%.3fs" % dt)
    except Exception as ex:
        emit(name, 0, repr(ex)[:60])

# disjoint input (gaps of 2 keep them separate) -> stays N intervals
timed("perf_merge",
      lambda: [[3*i, 3*i + 1] for i in range(N)],
      lambda d: merge(d),
      lambda out: len(out) == N)

# one giant overlapping chain -> O(n^2) rescanners die here
timed("perf_merge_chain",
      lambda: [[i, i + 5] for i in range(N)],
      lambda d: merge(d),
      lambda out: eq(out, [[0, N - 1 + 5]]))

# insert bridging a large disjoint list must be ~linear, not a full re-merge
timed("perf_insert",
      lambda: [[3*i, 3*i + 1] for i in range(N)],
      lambda d: insert(d, [1, 3*N]),
      lambda out: eq(out, [[0, 3*N]]))

# two-pointer intersect of two big lists -> linear; quadratic dies
timed("perf_intersect",
      lambda: ([[4*i, 4*i + 2] for i in range(N)], [[4*i + 1, 4*i + 3] for i in range(N)]),
      lambda d: intersect(d[0], d[1]),
      lambda out: len(out) == N)
PY
)
perf_rc=$?
echo "$PERF" >&2
[[ $perf_rc -ne 0 ]] && echo "PERF_RC=$perf_rc (perf probe timeout/crash -> missing lines default to 0)" >&2
# Fold the perf lines into the same stream the val_of/note_of helpers read.
RES="$RES
$PERF"

# Pull a single named check's value (2nd token) out of $RES, defaulting to 0 if
# the line is absent (e.g. the outer timeout killed a quadratic perf probe).
val_of() {
  local key="$1" v
  v=$(printf '%s\n' "$RES" | awk -v k="$key" '$1==k {print $2; exit}')
  [[ "$v" == "1" ]] && echo 1 || echo 0
}
note_of() {
  local key="$1"
  printf '%s\n' "$RES" | awk -v k="$key" '$1==k {$1="";$2="";sub(/^ +/,"");print;exit}'
}

# Declare EVERY behavioral check unconditionally at a fixed weight. Because
# val_of defaults to 0 for any missing line, the denominator is CONSTANT for
# every submission (empty stub, import-error, partial, correct, or hung).
# Weight philosophy: file/compile/import are cheap (a stub gets only those);
# happy-path checks are low; the bulk of the weight is on the HARD edge cases
# and the PERFORMANCE bound, so a quadratic happy-path-only solution lands in
# the middle of the range and only a fully correct O(n log n) reaches 100.

add "imports"              "$(val_of imports)"              4  "$(note_of imports)"

# merge happy path (a naive solution should get these) -- low weight
add "merge_overlap"        "$(val_of merge_overlap)"        3  "$(note_of merge_overlap)"
add "merge_unsorted"       "$(val_of merge_unsorted)"       3  "$(note_of merge_unsorted)"
add "merge_single"         "$(val_of merge_single)"         3  "$(note_of merge_single)"

# merge HARD edge cases -- heavy weight
add "merge_touch_endpoint" "$(val_of merge_touch_endpoint)" 7  "$(note_of merge_touch_endpoint)"
add "merge_int_adjacent"   "$(val_of merge_int_adjacent)"   7  "$(note_of merge_int_adjacent)"
add "merge_real_gap"       "$(val_of merge_real_gap)"       4  "$(note_of merge_real_gap)"
add "merge_containment"    "$(val_of merge_containment)"    5  "$(note_of merge_containment)"
add "merge_duplicates"     "$(val_of merge_duplicates)"     4  "$(note_of merge_duplicates)"
add "merge_empty"          "$(val_of merge_empty)"          4  "$(note_of merge_empty)"
add "merge_negative_chain" "$(val_of merge_negative_chain)" 6  "$(note_of merge_negative_chain)"
add "merge_validates"      "$(val_of merge_validates)"      6  "$(note_of merge_validates)"
add "merge_no_mutate"      "$(val_of merge_no_mutate)"      5  "$(note_of merge_no_mutate)"

# insert
add "insert_basic"         "$(val_of insert_basic)"         3  "$(note_of insert_basic)"
add "insert_empty"         "$(val_of insert_empty)"         4  "$(note_of insert_empty)"
add "insert_bridge"        "$(val_of insert_bridge)"        6  "$(note_of insert_bridge)"
add "insert_adjacent"      "$(val_of insert_adjacent)"      7  "$(note_of insert_adjacent)"
add "insert_gap"           "$(val_of insert_gap)"           4  "$(note_of insert_gap)"
add "insert_front"         "$(val_of insert_front)"         4  "$(note_of insert_front)"
add "insert_no_mutate"     "$(val_of insert_no_mutate)"     5  "$(note_of insert_no_mutate)"

# intersect
add "isect_basic"          "$(val_of isect_basic)"          6  "$(note_of isect_basic)"
add "isect_empty_a"        "$(val_of isect_empty_a)"        3  "$(note_of isect_empty_a)"
add "isect_empty_b"        "$(val_of isect_empty_b)"        3  "$(note_of isect_empty_b)"
add "isect_touch"          "$(val_of isect_touch)"          7  "$(note_of isect_touch)"
add "isect_disjoint"       "$(val_of isect_disjoint)"       4  "$(note_of isect_disjoint)"
add "isect_nested"         "$(val_of isect_nested)"         5  "$(note_of isect_nested)"

# PERFORMANCE -- heavy weight; quadratic solutions time out and lose all four
add "perf_merge"           "$(val_of perf_merge)"           9  "$(note_of perf_merge)"
add "perf_merge_chain"     "$(val_of perf_merge_chain)"     9  "$(note_of perf_merge_chain)"
add "perf_insert"          "$(val_of perf_insert)"          8  "$(note_of perf_insert)"
add "perf_intersect"       "$(val_of perf_intersect)"       8  "$(note_of perf_intersect)"

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
