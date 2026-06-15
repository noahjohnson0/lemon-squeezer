#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
# sanitize a note for safe embedding in JSON: drop backslashes, turn " into '
san() { printf '%s' "$1" | tr -d '\\' | tr '"' "'"; }
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  note="$(san "$note")"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/circuit.py"
HAVE_FILE=0; [[ -f "$T" ]] && HAVE_FILE=1
add "file:circuit.py" "$HAVE_FILE" 5

# compiles
COMPILES=0
if [[ "$HAVE_FILE" == "1" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && COMPILES=1
fi
add "compiles" "$COMPILES" 5

# Behavioral probe. The python block ALWAYS prints exactly one "name pass [note]"
# line per declared check via chk(), even on import error / exception, so the set
# of emitted behavioral lines (and therefore the denominator) is CONSTANT.
RES=""
if [[ "$HAVE_FILE" == "1" ]]; then
  RES=$(cd "$WS" && gtimeout 15 python3 - <<'PY' 2>>/dev/null
import sys

ok = True
try:
    from circuit import solve
except Exception as e:
    print("IMPORT_ERR", repr(e)[:60], file=sys.stderr)
    ok = False

print("imports", 1 if ok else 0)

def near(a, b, tol=1e-3):
    try:
        return abs(float(a) - float(b)) < tol
    except Exception:
        return False

def chk(name, fn, note=""):
    # ALWAYS prints a line for `name`. Import failure -> 0. Exception -> 0.
    if not ok:
        print(name, 0, "import failed")
        return
    try:
        passed, val = fn()
        print(name, 1 if passed else 0, val)
    except Exception as ex:
        print(name, 0, repr(ex)[:50])

# Voltage divider: V=10, R1=R2=1k -> vp=10, mid=5V
nl1 = "V1 vp gnd 10\nR1 vp n1 1000\nR2 n1 gnd 1000\n"
chk("vdiv_vp",  lambda: ((lambda r: (near(r.get("vp", 0), 10),  r.get("vp")))(solve(nl1))))
chk("vdiv_mid", lambda: ((lambda r: (near(r.get("n1", 0), 5),   r.get("n1")))(solve(nl1))))

# Three-resistor: vp -1- a, a -4|5- gnd. R_par=20/9; V(a)=10*(20/9)/(1+20/9)=200/29~6.8966
nl2 = "V1 vp gnd 10\nR1 vp a 1\nR2 a gnd 4\nR3 a gnd 5\n"
chk("threeR", lambda: ((lambda r: (near(r.get("a", 0), 6.8966, 0.01), r.get("a")))(solve(nl2))))

# Current source: 1 mA into 1k -> 1V across
nl3 = "I1 gnd n1 0.001\nR1 n1 gnd 1000\n"
chk("isource", lambda: ((lambda r: (near(r.get("n1", 0), 1.0), r.get("n1")))(solve(nl3))))

# Wheatstone (balanced): both midpoints = 5V
nl4 = "V1 vp gnd 10\nR1 vp a 100\nR2 vp b 200\nR3 a gnd 100\nR4 b gnd 200\n"
chk("wheat_a", lambda: ((lambda r: (near(r.get("a", 0), 5), r.get("a")))(solve(nl4))))
chk("wheat_b", lambda: ((lambda r: (near(r.get("b", 0), 5), r.get("b")))(solve(nl4))))

# Floating subnetwork: b,c only connect to each other -> must raise ValueError
nl5 = "V1 vp gnd 10\nR1 vp a 100\nR2 a gnd 200\nR3 b c 50\n"
def _float():
    try:
        solve(nl5)
        return (False, "no raise - must reject singular system")
    except ValueError:
        return (True, "raised ValueError")
    except Exception as ex:
        return (False, "wrong exc " + type(ex).__name__)
chk("floating_raises", _float)
PY
)
fi

# The full set of behavioral check names, in order. This list is FIXED so the
# denominator never changes - if the probe emitted no line for a name (file
# missing, python crashed before reaching it, gtimeout killed it), we still
# add that check as pass=0 below.
declare -a BNAMES=(imports vdiv_vp vdiv_mid threeR isource wheat_a wheat_b floating_raises)
BWEIGHT=11

# Parse whatever the probe emitted into name->"pass note" maps.
declare -A GOTPASS
declare -A GOTNOTE
if [[ -n "$RES" ]]; then
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(printf '%s' "$line" | awk '{print $1}')
    pass=$(printf '%s' "$line" | awk '{print $2}')
    note=$(printf '%s' "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    GOTPASS["$name"]="$pass"
    GOTNOTE["$name"]="$note"
  done < <(printf '%s\n' "$RES")
fi

# Emit every declared behavioral check exactly once, at the same weight, always.
for name in "${BNAMES[@]}"; do
  if [[ -n "${GOTPASS[$name]+x}" ]]; then
    add "$name" "${GOTPASS[$name]}" "$BWEIGHT" "${GOTNOTE[$name]:-}"
  else
    add "$name" 0 "$BWEIGHT" "no output (crash/timeout/missing file)"
  fi
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
