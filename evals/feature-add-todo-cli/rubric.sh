#!/usr/bin/env bash
# Score a feature-add-todo-cli workspace.
# Drives app/cli.py as a black box via subprocess in a scratch store and
# asserts stdout, exit codes, and persisted JSON state across ~8 checks.
set -u
WS="${1:?workspace dir required}"
[[ -d "$WS" ]] || { echo "{\"error\":\"workspace not found\"}"; exit 1; }

declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  # sanitize note: drop backslashes, turn double quotes into single quotes
  note="${note//\\/}"
  note="${note//\"/\'}"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

CLI="$WS/app/cli.py"
STORAGE="$WS/app/storage.py"
add "file:app/cli.py" "$([[ -f "$CLI" ]] && echo 1 || echo 0)" 4
add "file:app/storage.py" "$([[ -f "$STORAGE" ]] && echo 1 || echo 0)" 2

NAMES="compiles add_list done_marks done_persists done_bad_id list_pending rm_removes rm_keeps_ids rm_bad_id"

if [[ -f "$CLI" && -f "$STORAGE" ]]; then
  python3 -m py_compile "$CLI" 2>/dev/null && add "compiles" 1 6 || add "compiles" 0 6

  RES=$(gtimeout 30 python3 - "$WS" <<'PY' 2>&1
import json, os, subprocess, sys, tempfile

ws = sys.argv[1]
cli = os.path.join(ws, "app", "cli.py")

scratch = tempfile.mkdtemp()
db = os.path.join(scratch, "todo.json")

def run(*args):
    env = dict(os.environ)
    env["TODO_DB"] = db
    env["HOME"] = scratch
    p = subprocess.run(
        [sys.executable, cli, *args],
        capture_output=True, text=True, env=env, timeout=15,
    )
    return p.returncode, p.stdout, p.stderr

def reset():
    try:
        os.remove(db)
    except OSError:
        pass

def state():
    if not os.path.exists(db):
        return []
    with open(db, encoding="utf-8") as fh:
        return json.load(fh)

def emit(name, ok, note=""):
    print(f"{name}\t{1 if ok else 0}\t{note}")

# --- baseline: add + plain list (should already work) ---------------------
reset()
rc1, o1, _ = run("add", "buy milk")
rc2, o2, _ = run("add", "walk the dog")
rc3, o3, _ = run("add", "pay rent")
rcl, ol, _ = run("list")
ol_lines = [l for l in ol.splitlines() if l.strip()]
expected_list = ["[ ] #1 buy milk", "[ ] #2 walk the dog", "[ ] #3 pay rent"]
emit("add_list",
     rc1 == 0 and rc2 == 0 and rc3 == 0 and rcl == 0 and ol_lines == expected_list,
     f"list={ol_lines!r}")

# --- done #2: stdout + exit ----------------------------------------------
# (store currently has 1,2,3 all pending)
rcd, od, _ = run("done", "2")
done_ok = rcd == 0 and od.strip() == "done #2"
emit("done_marks",
     done_ok,
     f"rc={rcd} out={od.strip()!r}")

# --- done persisted to disk ----------------------------------------------
st = state()
by_id = {t["id"]: t for t in st}
emit("done_persists",
     by_id.get(2, {}).get("done") is True
     and by_id.get(1, {}).get("done") is False
     and by_id.get(3, {}).get("done") is False,
     f"state={st!r}")

# --- done with a non-existent id -> nonzero, no 'done #' on stdout --------
# Only counts if the happy path also works, so a NotImplementedError stub
# (which crashes on everything and thus "exits non-zero") gets no credit.
rcb, ob, eb = run("done", "999")
emit("done_bad_id",
     done_ok and rcb != 0 and "done #999" not in ob,
     f"happy_ok={done_ok} rc={rcb} out={ob.strip()!r}")

# --- list --pending shows only undone tasks (#1 and #3 here) -------------
rcp, op, _ = run("list", "--pending")
op_lines = [l for l in op.splitlines() if l.strip()]
expected_pending = ["[ ] #1 buy milk", "[ ] #3 pay rent"]
emit("list_pending",
     rcp == 0 and op_lines == expected_pending,
     f"pending={op_lines!r}")

# --- rm #1 removes it, prints 'removed #1', exit 0 -----------------------
rcr, orr, _ = run("rm", "1")
after = state()
ids_after = sorted(t["id"] for t in after)
rm_ok = rcr == 0 and orr.strip() == "removed #1" and 1 not in ids_after
emit("rm_removes",
     rm_ok,
     f"rc={rcr} out={orr.strip()!r} ids={ids_after}")

# --- rm keeps the other ids unchanged (2 and 3 still present) ------------
emit("rm_keeps_ids",
     ids_after == [2, 3],
     f"ids={ids_after}")

# --- rm with a non-existent id -> nonzero, no 'removed #' on stdout -------
# Gated on the happy path working (same anti-stub reasoning as done_bad_id).
rcx, ox, ex = run("rm", "424242")
emit("rm_bad_id",
     rm_ok and rcx != 0 and "removed #424242" not in ox,
     f"happy_ok={rm_ok} rc={rcx} out={ox.strip()!r}")
PY
)
  echo "$RES" >&2

  for n in add_list done_marks done_persists done_bad_id list_pending rm_removes rm_keeps_ids rm_bad_id; do
    line=$(printf '%s\n' "$RES" | grep -E "^$n	" | head -n1)
    if [[ -z "$line" ]]; then
      add "$n" 0 11 "no result (crash?)"
    else
      pass=$(printf '%s' "$line" | cut -f2)
      note=$(printf '%s' "$line" | cut -f3-)
      add "$n" "$pass" 11 "$note"
    fi
  done
else
  for n in $NAMES; do add "$n" 0 6; done
fi

# emit
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
