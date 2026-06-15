#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks

# Portable timeout: prefer gtimeout (coreutils), fall back to timeout(1).
TO="$(command -v gtimeout || command -v timeout)"

# Sanitize notes so the emitted JSON stays valid: drop backslashes, turn
# double-quotes into single-quotes, collapse tabs/newlines.
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
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/resolver.py"

# --- static checks (always emitted) ---------------------------------------
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:resolver.py" "$file_ok" 3

compile_ok=0
if [[ "$file_ok" == "1" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && compile_ok=1
fi
add "compiles" "$compile_ok" 3

# --- behavioral + perf checks ---------------------------------------------
# The python heredoc ALWAYS prints exactly one line per declared check (via
# chk()), whether the import works or not, so the denominator is CONSTANT for
# every submission (empty stub, import-error, partial, correct).
#
# Declared check names + weights live HERE so we can seed defaults to 0 and
# never drop a check even if the interpreter crashes mid-run.
declare -a NAMES=(
  imports
  happy_order happy_root_last diamond_once subset_only
  tie_alpha tie_wide single_node
  cycle_raises cycle_path cycle_self cycle_canonical cycle_deep
  missing_raises missing_attr missing_root missing_smallest
  big_correct
  perf_big
)
declare -A WEIGHT=(
  [imports]=3
  [happy_order]=4 [happy_root_last]=3 [diamond_once]=5 [subset_only]=5
  [tie_alpha]=7 [tie_wide]=7 [single_node]=2
  [cycle_raises]=4 [cycle_path]=8 [cycle_self]=6 [cycle_canonical]=8 [cycle_deep]=6
  [missing_raises]=4 [missing_attr]=7 [missing_root]=5 [missing_smallest]=7
  [big_correct]=6
  [perf_big]=12
)
declare -A SCORE; declare -A NOTE
for n in "${NAMES[@]}"; do SCORE["$n"]=0; NOTE["$n"]="no output from rubric"; done

RES=""
if [[ "$file_ok" == "1" ]]; then
  # cwd=WS so `import resolver` works; outer gtimeout is a hard backstop, the
  # perf case has its own inner deadline so it fails as 0 instead of killing
  # the whole probe.
  RES=$("$TO" 25 python3 - "$WS" <<'PY' 2>/dev/null
import sys, os
ws = sys.argv[1]
sys.path.insert(0, ws)

ok = True
err = ""
try:
    from resolver import resolve, CycleError, MissingDependencyError
except Exception as e:
    err = repr(e)[:70]
    ok = False

def emit(name, passed, note=""):
    note = str(note).replace("\\", "").replace('"', "'").replace("\n", " ").replace("\t", " ")
    print(name, 1 if passed else 0, note)

def chk(name, fn):
    if not ok:
        emit(name, 0, "import failed")
        return
    try:
        emit(name, 1 if fn() else 0)
    except Exception as ex:
        emit(name, 0, repr(ex)[:50])

emit("imports", ok, "" if ok else err)

# ---- happy path -------------------------------------------------------
G1 = {"app": ["db", "web"], "web": ["util"], "db": ["util"], "util": []}
chk("happy_order", lambda: resolve(G1, "app") == ["util", "db", "web", "app"])
chk("happy_root_last", lambda: resolve(G1, "app")[-1] == "app")

# diamond installed exactly once
def diamond_once():
    out = resolve(G1, "app")
    return out.count("util") == 1 and sorted(out) == ["app", "db", "util", "web"]
chk("diamond_once", diamond_once)

# only the reachable subgraph (z, orphan are unrelated keys)
def subset_only():
    g = {"a": ["b"], "b": [], "z": ["a"], "orphan": []}
    out = resolve(g, "a")
    return out == ["b", "a"]
chk("subset_only", subset_only)

# ---- deterministic alphabetical tie-break -----------------------------
# r depends on three independent leaves; they must come out alphabetically.
def tie_alpha():
    g = {"r": ["c", "a", "b"], "a": [], "b": [], "c": []}
    return resolve(g, "r") == ["a", "b", "c", "r"]
chk("tie_alpha", tie_alpha)

# wider: two layers where many nodes free up at once. The ONLY valid
# deterministic order is the alphabetical one; any other ordering means the
# tie-break is not implemented.
def tie_wide():
    g = {
        "top": ["m1", "m2"],
        "m1": ["x", "y"],
        "m2": ["y", "z"],
        "x": [], "y": [], "z": [],
    }
    # Lexicographically-smallest topological order (at every step install the
    # alphabetically-smallest currently-installable package): x, then y (which
    # frees m1), then m1 sorts before z so m1, then z (frees m2), then m2, top.
    return resolve(g, "top") == ["x", "y", "m1", "z", "m2", "top"]
chk("tie_wide", tie_wide)

chk("single_node", lambda: resolve({"solo": []}, "solo") == ["solo"])

# ---- cycle detection --------------------------------------------------
def cycle_raises():
    try:
        resolve({"A": ["B"], "B": ["A"]}, "A")
    except CycleError:
        return True
    return False
chk("cycle_raises", cycle_raises)

# the cycle path must be reported and actually describe the loop (closed,
# every consecutive pair is a real edge).
def cycle_path():
    try:
        resolve({"A": ["B"], "B": ["C"], "C": ["A"]}, "A")
    except CycleError as e:
        cyc = list(getattr(e, "cycle"))
        if len(cyc) < 2 or cyc[0] != cyc[-1]:
            return False
        g = {"A": ["B"], "B": ["C"], "C": ["A"]}
        for u, v in zip(cyc, cyc[1:]):
            if v not in g.get(u, []):
                return False
        # must contain the whole loop (3 distinct nodes)
        return set(cyc) == {"A", "B", "C"}
    return False
chk("cycle_path", cycle_path)

# self-dependency is the cycle [X, X]
def cycle_self():
    try:
        resolve({"X": ["X"]}, "X")
    except CycleError as e:
        return list(getattr(e, "cycle")) == ["X", "X"]
    return False
chk("cycle_self", cycle_self)

# canonical rotation: starts at alphabetically-smallest node in the loop.
def cycle_canonical():
    # loop B->C->B reachable from root A. Canonical rotation starts at B.
    try:
        resolve({"A": ["C"], "C": ["B"], "B": ["C"]}, "A")
    except CycleError as e:
        return list(getattr(e, "cycle")) == ["B", "C", "B"]
    return False
chk("cycle_canonical", cycle_canonical)

# cycle buried deep behind a long healthy chain
def cycle_deep():
    g = {"a": ["b"], "b": ["c"], "c": ["d"], "d": ["e"], "e": ["c"]}
    try:
        resolve(g, "a")
    except CycleError as e:
        cyc = list(getattr(e, "cycle"))
        return cyc[0] == cyc[-1] and set(cyc) == {"c", "d", "e"} and cyc[0] == "c"
    return False
chk("cycle_deep", cycle_deep)

# ---- missing dependency ----------------------------------------------
def missing_raises():
    try:
        resolve({"A": ["B"], "B": ["ghost"]}, "A")
    except MissingDependencyError:
        return True
    return False
chk("missing_raises", missing_raises)

def missing_attr():
    try:
        resolve({"A": ["B"], "B": ["ghost"]}, "A")
    except MissingDependencyError as e:
        return getattr(e, "missing") == "ghost"
    return False
chk("missing_attr", missing_attr)

def missing_root():
    try:
        resolve({"A": []}, "nope")
    except MissingDependencyError as e:
        return getattr(e, "missing") == "nope"
    return False
chk("missing_root", missing_root)

# several missing -> alphabetically smallest
def missing_smallest():
    try:
        resolve({"A": ["zzz", "aaa", "B"], "B": []}, "A")
    except MissingDependencyError as e:
        return getattr(e, "missing") == "aaa"
    return False
chk("missing_smallest", missing_smallest)

# ---- big correctness (SHALLOW wide graph; depth 3, so a correct iterative
#      OR recursive solver both pass - it does not require deep recursion) ---
def build_big(n):
    # root -> m_0..m_{n-1}; each m_i -> a distinct leaf l_{n-1-i}. The reversed
    # indexing means the alphabetically-first ready node is the LAST one a
    # front-to-back rescan finds, which is what makes a quadratic resolver slow.
    g = {}
    for j in range(n):
        g["l%06d" % j] = []
    for i in range(n):
        g["m%06d" % i] = ["l%06d" % (n - 1 - i)]
    g["root"] = ["m%06d" % i for i in range(n)]
    return g

def valid_topo(g, root, out):
    # out must: be a permutation of reachable nodes, place every dep before
    # its dependant, install each exactly once.
    if len(out) != len(set(out)):
        return False
    pos = {x: i for i, x in enumerate(out)}
    if root not in pos or pos[root] != len(out) - 1:
        return False
    # reachable set
    seen = set(); st = [root]
    while st:
        u = st.pop()
        if u in seen:
            continue
        seen.add(u)
        for d in g[u]:
            st.append(d)
    if set(out) != seen:
        return False
    for u in seen:
        for d in g[u]:
            if pos[d] >= pos[u]:
                return False
    return True

def big_correct():
    g = build_big(2000)
    out = resolve(g, "root")
    return valid_topo(g, "root", out)
chk("big_correct", big_correct)

# ---- PERFORMANCE ------------------------------------------------------
# A linear (O(V+E)) resolver finishes this SHALLOW 30k-module graph in a
# fraction of a second (depth 3, so no deep recursion is required); an
# O(V^2) repeated-scan resolver needs billions of operations and blows the
# inner deadline. resolve runs in a SEPARATE worker process with its own
# hard wall-clock limit: if it doesn't return in time, perf_big = 0 and the
# main probe is NOT killed - the failure is isolated to this one check.
def perf_big():
    n = 45000
    code = (
        "import sys; sys.path.insert(0, %r)\n"
        "from resolver import resolve\n"
        "g={}\n"
        "for j in range(%d): g['l%%06d'%%j]=[]\n"
        "for i in range(%d): g['m%%06d'%%i]=['l%%06d'%%(%d-1-i)]\n"
        "g['root']=['m%%06d'%%i for i in range(%d)]\n"
        "out=resolve(g,'root')\n"
        "assert len(out)==2*%d+1, len(out)\n"
        "assert out[-1]=='root'\n"
        "print('OK')\n"
    ) % (ws, n, n, n, n, n)
    import subprocess
    try:
        p = subprocess.run([sys.executable, "-c", code],
                           capture_output=True, timeout=6)
    except subprocess.TimeoutExpired:
        return False
    return p.returncode == 0 and b"OK" in p.stdout
chk("perf_big", perf_big)
PY
)
fi
echo "$RES" >&2

# Parse emitted lines into the seeded maps.
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  [[ "$name" == "IMPORT_ERR" ]] && continue
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  if [[ -n "${SCORE[$name]+x}" ]]; then
    SCORE["$name"]="$pass"
    NOTE["$name"]="$note"
  fi
done < <(printf '%s\n' "$RES")

# Emit every declared behavioral check at its fixed weight, ALWAYS.
for n in "${NAMES[@]}"; do
  add "$n" "${SCORE[$n]}" "${WEIGHT[$n]}" "${NOTE[$n]}"
done

# --- emit JSON (the ONLY thing on stdout) ---------------------------------
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
