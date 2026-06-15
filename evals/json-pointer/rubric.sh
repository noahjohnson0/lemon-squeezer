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

# Portable timeout: gtimeout (coreutils on mac) or timeout (linux).
TO="$(command -v gtimeout || command -v timeout)"

T="$WS/jsonptr.py"
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:jsonptr.py" "$file_ok" 4

compile_ok=0
if [[ "$file_ok" == "1" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && compile_ok=1
fi
add "compiles" "$compile_ok" 4

# Static anti-cheat: must implement RFC 6901/6902 by hand, not delegate to a
# third-party library. Only credited when there is an importable solution
# (otherwise an empty stub games this absence-check for free); gated below.
lib_clean=1
if [[ "$file_ok" == "1" ]]; then
  if grep -qE "import[[:space:]]+jsonpatch|import[[:space:]]+jsonpointer|from[[:space:]]+jsonpatch|from[[:space:]]+jsonpointer" "$T"; then
    lib_clean=0
  fi
fi

# Behavioral + perf probe. The python ALWAYS prints exactly one line per
# declared check (chk() never aborts the rest, never sys.exit's). First token
# is the check name, second is 1/0, remainder is a free-form note. The
# "imports" line reflects whether the API imported at all. Everything is on
# stderr EXCEPT the per-check lines on stdout, which we turn into scores below.
# No JSON is produced here.
RES=$(cd "$WS" && "$TO" 25 python3 - <<'PY' 2>/dev/null
import sys, copy, time

ok = True
try:
    from jsonptr import resolve, apply
except Exception as e:
    sys.stderr.write("IMPORT_ERR %r\n" % (e,))
    ok = False

def chk(name, fn):
    # ALWAYS prints exactly one line: name pass [note]. Never raises out.
    if not ok:
        print(name, 0, "no_import")
        return
    try:
        print(name, 1 if fn() else 0)
    except Exception as ex:
        note = repr(ex)[:60].replace("\\", "/").replace('"', "'").replace("\n", " ")
        print(name, 0, note)

print("imports", 1 if ok else 0)

# ---- helpers ---------------------------------------------------------------
def raises(exc, fn):
    """True iff fn() raises an instance of exc (and not some other error)."""
    try:
        fn()
    except exc:
        return True
    except Exception:
        return False
    return False

DOC = {
    "foo": ["bar", "baz"],
    "": 0,
    "a/b": 1,
    "c%d": 2,
    "e^f": 3,
    "g|h": 4,
    "i\\j": 5,
    "k\"l": 6,
    " ": 7,
    "m~n": 8,
    "nested": {"x": [10, 20, {"y": 30}]},
}

# ============================ resolve: happy path ===========================
def t_resolve_whole():
    return resolve(DOC, "") is DOC or resolve(DOC, "") == DOC

def t_resolve_array_elem():
    return resolve(DOC, "/foo/0") == "bar" and resolve(DOC, "/foo/1") == "baz"

def t_resolve_nested():
    return resolve(DOC, "/nested/x/2/y") == 30

# ====================== resolve: RFC 6901 escaping edge =====================
def t_escape_slash():
    # ~1 -> '/' : key "a/b"
    return resolve(DOC, "/a~1b") == 1

def t_escape_tilde():
    # ~0 -> '~' : key "m~n"
    return resolve(DOC, "/m~0n") == 8

def t_escape_order():
    # "~01" must unescape to "~1" (do ~1 first, then ~0), NOT to "/".
    d = {"~1": "tilde-one", "/": "slash"}
    return resolve(d, "/~01") == "tilde-one"

def t_empty_key():
    # key "" is reachable as "/"
    return resolve(DOC, "/") == 0

def t_literal_specials():
    return (resolve(DOC, "/c%d") == 2 and resolve(DOC, "/e^f") == 3
            and resolve(DOC, "/g|h") == 4 and resolve(DOC, "/ ") == 7)

# ====================== resolve: error edge cases ===========================
def t_missing_key():
    return raises(KeyError, lambda: resolve(DOC, "/nope"))

def t_no_leading_slash():
    # non-empty pointer not starting with '/' is malformed -> ValueError
    return raises(ValueError, lambda: resolve(DOC, "foo"))

def t_array_oob():
    return raises(KeyError, lambda: resolve(DOC, "/foo/2"))

def t_array_dash_resolve():
    # '-' is never a valid resolve target
    return raises(KeyError, lambda: resolve(DOC, "/foo/-"))

def t_array_leading_zero():
    # "01" is not a valid array index token -> KeyError
    return raises(KeyError, lambda: resolve(DOC, "/foo/01"))

def t_array_nonint():
    return raises(KeyError, lambda: resolve(DOC, "/foo/bar"))

def t_descend_into_scalar():
    # foo/0 is "bar" (a string scalar); descending further must fail
    return raises(KeyError, lambda: resolve(DOC, "/foo/0/0"))

# ============================ apply: happy path =============================
def t_add_obj():
    d = {"a": 1}
    out = apply(d, [{"op": "add", "path": "/b", "value": 2}])
    return out == {"a": 1, "b": 2}

def t_replace():
    d = {"a": 1}
    out = apply(d, [{"op": "replace", "path": "/a", "value": 9}])
    return out == {"a": 9}

def t_remove():
    d = {"a": 1, "b": 2}
    out = apply(d, [{"op": "remove", "path": "/a"}])
    return out == {"b": 2}

# ====================== apply: array insert/append rules ====================
def t_add_array_insert():
    d = {"l": [1, 2, 3]}
    out = apply(d, [{"op": "add", "path": "/l/1", "value": 99}])
    return out == {"l": [1, 99, 2, 3]}

def t_add_array_append_index():
    d = {"l": [1, 2, 3]}
    out = apply(d, [{"op": "add", "path": "/l/3", "value": 4}])
    return out == {"l": [1, 2, 3, 4]}

def t_add_array_dash():
    d = {"l": [1, 2, 3]}
    out = apply(d, [{"op": "add", "path": "/l/-", "value": 4}])
    return out == {"l": [1, 2, 3, 4]}

def t_add_array_oob():
    d = {"l": [1, 2, 3]}
    return raises(IndexError, lambda: apply(d, [{"op": "add", "path": "/l/9", "value": 4}]))

def t_remove_array_shift():
    d = {"l": [1, 2, 3]}
    out = apply(d, [{"op": "remove", "path": "/l/0"}])
    return out == {"l": [2, 3]}

# ============================== apply: move =================================
def t_move():
    d = {"a": {"b": 1}, "c": {}}
    out = apply(d, [{"op": "move", "from": "/a/b", "path": "/c/b"}])
    return out == {"a": {}, "c": {"b": 1}}

def t_move_array_reorder():
    d = {"l": [1, 2, 3]}
    out = apply(d, [{"op": "move", "from": "/l/0", "path": "/l/2"}])
    return out == {"l": [2, 3, 1]}

def t_move_into_own_child():
    # RFC 6902: 'from' must not be a proper prefix of 'path'.
    d = {"a": {"b": {}}}
    return raises(ValueError, lambda: apply(d, [{"op": "move", "from": "/a", "path": "/a/b/c"}]))

# ============================== apply: test ================================
def t_test_pass():
    d = {"a": [1, 2, 3]}
    out = apply(d, [{"op": "test", "path": "/a", "value": [1, 2, 3]}])
    return out == {"a": [1, 2, 3]}

def t_test_fail():
    d = {"a": 1}
    return raises(ValueError, lambda: apply(d, [{"op": "test", "path": "/a", "value": 2}]))

def t_test_bool_vs_int():
    # True must NOT deep-equal 1: test of value True against doc 1 must FAIL.
    d = {"a": 1}
    return raises(ValueError, lambda: apply(d, [{"op": "test", "path": "/a", "value": True}]))

# ===================== apply: error + unknown op ===========================
def t_replace_missing():
    d = {"a": 1}
    return raises(KeyError, lambda: apply(d, [{"op": "replace", "path": "/b", "value": 2}]))

def t_remove_missing():
    d = {"a": 1}
    return raises(KeyError, lambda: apply(d, [{"op": "remove", "path": "/b"}]))

def t_unknown_op():
    d = {"a": 1}
    return raises(ValueError, lambda: apply(d, [{"op": "frobnicate", "path": "/a", "value": 2}]))

def t_add_root():
    d = {"a": 1}
    out = apply(d, [{"op": "add", "path": "", "value": {"z": 9}}])
    return out == {"z": 9}

# =========================== apply: ATOMICITY ==============================
def t_atomic_no_mutate_success():
    # On success the INPUT must be untouched (apply returns a new doc).
    d = {"l": [1, 2, 3], "k": "v"}
    snap = copy.deepcopy(d)
    apply(d, [{"op": "add", "path": "/l/0", "value": 0}, {"op": "remove", "path": "/k"}])
    return d == snap

def t_atomic_no_mutate_failure():
    # A patch that fails on its 2nd op must leave the input EXACTLY as it was
    # (no partial application visible on the caller's object).
    d = {"l": [1, 2, 3], "m": {"n": 5}}
    snap = copy.deepcopy(d)
    threw = raises(Exception, lambda: apply(d, [
        {"op": "add", "path": "/l/-", "value": 99},   # would succeed
        {"op": "remove", "path": "/does_not_exist"},  # fails -> rollback
    ]))
    return threw and d == snap

def t_atomic_returned_independent():
    # The returned doc must be a deep copy: mutating it must not affect input.
    d = {"l": [1, 2, 3]}
    out = apply(d, [{"op": "replace", "path": "/l/0", "value": 7}])
    out["l"].append(123)
    return d == {"l": [1, 2, 3]}

# ============================ PERFORMANCE =================================
def t_perf_large():
    # A handful of shallow ops against a 200k-element list must be fast.
    # A correct impl touches O(depth) per pointer; a quadratic impl that
    # re-walks / re-copies the whole list per token blows the timeout.
    N = 200000
    big = {"items": list(range(N)), "meta": {"count": N}}
    ops = []
    for i in range(300):
        ops.append({"op": "replace", "path": "/items/%d" % (i * 11), "value": -i})
        ops.append({"op": "test", "path": "/meta/count", "value": N})
    t0 = time.time()
    out = apply(big, ops)
    dt = time.time() - t0
    sys.stderr.write("perf_dt=%.3fs\n" % dt)
    if out["items"][0] != 0 or out["items"][11] != -1:
        return False
    return dt < 4.0

def t_perf_resolve():
    # Deep resolve must be O(depth), not O(depth^2) (no per-token full copy).
    depth = 4000
    node = cur = {}
    for i in range(depth):
        nxt = {}
        cur["k"] = nxt
        cur = nxt
    cur["v"] = 42
    ptr = "/k" * depth + "/v"
    t0 = time.time()
    r = resolve(node, ptr)
    dt = time.time() - t0
    sys.stderr.write("perf_resolve_dt=%.3fs\n" % dt)
    return r == 42 and dt < 3.0

# ---- run all (order is informational; every check prints exactly one line) --
chk("resolve_whole", t_resolve_whole)
chk("resolve_array_elem", t_resolve_array_elem)
chk("resolve_nested", t_resolve_nested)
chk("escape_slash", t_escape_slash)
chk("escape_tilde", t_escape_tilde)
chk("escape_order", t_escape_order)
chk("empty_key", t_empty_key)
chk("literal_specials", t_literal_specials)
chk("missing_key", t_missing_key)
chk("no_leading_slash", t_no_leading_slash)
chk("array_oob", t_array_oob)
chk("array_dash_resolve", t_array_dash_resolve)
chk("array_leading_zero", t_array_leading_zero)
chk("array_nonint", t_array_nonint)
chk("descend_into_scalar", t_descend_into_scalar)
chk("add_obj", t_add_obj)
chk("replace", t_replace)
chk("remove", t_remove)
chk("add_array_insert", t_add_array_insert)
chk("add_array_append_index", t_add_array_append_index)
chk("add_array_dash", t_add_array_dash)
chk("add_array_oob", t_add_array_oob)
chk("remove_array_shift", t_remove_array_shift)
chk("move", t_move)
chk("move_array_reorder", t_move_array_reorder)
chk("move_into_own_child", t_move_into_own_child)
chk("test_pass", t_test_pass)
chk("test_fail", t_test_fail)
chk("test_bool_vs_int", t_test_bool_vs_int)
chk("replace_missing", t_replace_missing)
chk("remove_missing", t_remove_missing)
chk("unknown_op", t_unknown_op)
chk("add_root", t_add_root)
chk("atomic_no_mutate_success", t_atomic_no_mutate_success)
chk("atomic_no_mutate_failure", t_atomic_no_mutate_failure)
chk("atomic_returned_independent", t_atomic_returned_independent)
chk("perf_large", t_perf_large)
chk("perf_resolve", t_perf_resolve)
PY
)
probe_rc=$?
echo "$RES" >&2
[[ $probe_rc -ne 0 ]] && echo "PROBE_RC=$probe_rc (timeout/crash -> missing lines default to 0)" >&2

# Pull a single named check out of $RES (second token), default 0 if absent
# (e.g. the timeout killed python before that line was emitted).
val_of() {
  local key="$1" line
  line=$(echo "$RES" | awk -v k="$key" '$1==k {print $2; exit}')
  [[ "$line" == "1" ]] && echo 1 || echo 0
}
note_of() {
  local key="$1"
  echo "$RES" | awk -v k="$key" '$1==k {$1="";$2="";sub(/^ +/,"");print;exit}'
}

# Did the solution actually import? Gate the static anti-cheat on this so a
# trivial/empty stub cannot earn the no_third_party_lib point for free.
import_ok="$(val_of imports)"
if [[ "$import_ok" == "1" && "$lib_clean" == "1" ]]; then
  add "no_third_party_lib" 1 6
else
  if [[ "$import_ok" != "1" ]]; then
    add "no_third_party_lib" 0 6 "no importable solution"
  else
    add "no_third_party_lib" 0 6 "uses jsonpatch/jsonpointer"
  fi
fi

# Declare EVERY behavioral check unconditionally with a fixed weight. Because
# val_of defaults to 0 for any line the probe failed to emit, the denominator
# is constant regardless of how broken the submission is. Weights put MOST of
# the mass on the hard edge cases + atomicity + performance, not the happy path.

# import / happy path (low weight)
add "imports"                     "$(val_of imports)"                     6 "$(note_of imports)"
add "resolve_whole"               "$(val_of resolve_whole)"               2 "$(note_of resolve_whole)"
add "resolve_array_elem"          "$(val_of resolve_array_elem)"          2 "$(note_of resolve_array_elem)"
add "resolve_nested"              "$(val_of resolve_nested)"              2 "$(note_of resolve_nested)"
add "add_obj"                     "$(val_of add_obj)"                     2 "$(note_of add_obj)"
add "replace"                     "$(val_of replace)"                     2 "$(note_of replace)"
add "remove"                      "$(val_of remove)"                      2 "$(note_of remove)"

# RFC 6901 escaping edge cases (high weight - the meat)
add "escape_slash"                "$(val_of escape_slash)"                7 "$(note_of escape_slash)"
add "escape_tilde"                "$(val_of escape_tilde)"                7 "$(note_of escape_tilde)"
add "escape_order"                "$(val_of escape_order)"                9 "$(note_of escape_order)"
add "empty_key"                   "$(val_of empty_key)"                   5 "$(note_of empty_key)"
add "literal_specials"            "$(val_of literal_specials)"            4 "$(note_of literal_specials)"

# resolve error edges (high weight)
add "missing_key"                 "$(val_of missing_key)"                 4 "$(note_of missing_key)"
add "no_leading_slash"            "$(val_of no_leading_slash)"            5 "$(note_of no_leading_slash)"
add "array_oob"                   "$(val_of array_oob)"                   5 "$(note_of array_oob)"
add "array_dash_resolve"          "$(val_of array_dash_resolve)"          6 "$(note_of array_dash_resolve)"
add "array_leading_zero"          "$(val_of array_leading_zero)"          7 "$(note_of array_leading_zero)"
add "array_nonint"                "$(val_of array_nonint)"                4 "$(note_of array_nonint)"
add "descend_into_scalar"         "$(val_of descend_into_scalar)"         5 "$(note_of descend_into_scalar)"

# array insert/append rules (high weight)
add "add_array_insert"            "$(val_of add_array_insert)"            7 "$(note_of add_array_insert)"
add "add_array_append_index"      "$(val_of add_array_append_index)"      5 "$(note_of add_array_append_index)"
add "add_array_dash"              "$(val_of add_array_dash)"              6 "$(note_of add_array_dash)"
add "add_array_oob"               "$(val_of add_array_oob)"               6 "$(note_of add_array_oob)"
add "remove_array_shift"          "$(val_of remove_array_shift)"          4 "$(note_of remove_array_shift)"

# move (high weight - own-child prefix rule is subtle)
add "move"                        "$(val_of move)"                        4 "$(note_of move)"
add "move_array_reorder"          "$(val_of move_array_reorder)"          6 "$(note_of move_array_reorder)"
add "move_into_own_child"         "$(val_of move_into_own_child)"         8 "$(note_of move_into_own_child)"

# test op (bool-vs-int is the subtle one)
add "test_pass"                   "$(val_of test_pass)"                   3 "$(note_of test_pass)"
add "test_fail"                   "$(val_of test_fail)"                   3 "$(note_of test_fail)"
add "test_bool_vs_int"            "$(val_of test_bool_vs_int)"            8 "$(note_of test_bool_vs_int)"

# apply error handling
add "replace_missing"             "$(val_of replace_missing)"             4 "$(note_of replace_missing)"
add "remove_missing"              "$(val_of remove_missing)"              4 "$(note_of remove_missing)"
add "unknown_op"                  "$(val_of unknown_op)"                  4 "$(note_of unknown_op)"
add "add_root"                    "$(val_of add_root)"                    4 "$(note_of add_root)"

# ATOMICITY (high weight - the headline hard property)
add "atomic_no_mutate_success"    "$(val_of atomic_no_mutate_success)"    8 "$(note_of atomic_no_mutate_success)"
add "atomic_no_mutate_failure"    "$(val_of atomic_no_mutate_failure)"   12 "$(note_of atomic_no_mutate_failure)"
add "atomic_returned_independent" "$(val_of atomic_returned_independent)"  8 "$(note_of atomic_returned_independent)"

# PERFORMANCE (high weight - quadratic impls blow the timeout -> 0)
add "perf_large"                  "$(val_of perf_large)"                  12 "$(note_of perf_large)"
add "perf_resolve"                "$(val_of perf_resolve)"                 8 "$(note_of perf_resolve)"

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
