#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks

# sanitize a note: strip backslashes and double-quotes so the JSON stays valid
san() { printf '%s' "$1" | tr -d '\\' | tr '"' "'"; }

add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  note=$(san "$note")
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/kalman.py"

# ----------------------------------------------------------------------------
# Static checks. file:kalman.py and compiles are ALWAYS emitted.
# ----------------------------------------------------------------------------
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:kalman.py" "$file_ok" 5

compiles=0
if [[ "$file_ok" == "1" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && compiles=1
fi
add "compiles" "$compiles" 5

# ----------------------------------------------------------------------------
# Behavioral checks. The python block below ALWAYS prints exactly one line per
# declared check (name pass [note]) - even on import failure or mid-run
# exception - so the denominator is CONSTANT across stub / import-error /
# partial / correct submissions. We declare the canonical name->weight table
# here and only honour lines whose name is declared, defaulting any missing
# line to pass=0. This makes the denominator independent of the submission.
# ----------------------------------------------------------------------------
declare -a BNAMES=(
  imports
  init
  cov_2x2
  converge_pos
  converge_vel
  predict_advances
  predict_grows_cov
)
declare -A BWEIGHT=(
  [imports]=11
  [init]=11
  [cov_2x2]=11
  [converge_pos]=11
  [converge_vel]=11
  [predict_advances]=11
  [predict_grows_cov]=11
)
declare -A BPASS BNOTE
for n in "${BNAMES[@]}"; do BPASS[$n]=0; BNOTE[$n]=""; done

if [[ "$file_ok" == "1" ]]; then
  RES=$(cd "$WS" && gtimeout 15 python3 - <<'PY' 2>&1
import sys, random
ok = True
try:
    from kalman import Kalman1D
except Exception as e:
    print("IMPORT_ERR", repr(e)[:120], file=sys.stderr)
    ok = False

# imports check reflects the import flag directly.
print("imports", 1 if ok else 0)

def chk(name, fn):
    # ALWAYS prints a line for `name`; import failure -> 0, exception -> 0.
    if not ok:
        print(name, 0)
        return
    try:
        res = fn()
        print(name, 1 if res else 0)
    except Exception as ex:
        print(name, 0, repr(ex)[:60])

random.seed(42)

# --- Test 1: interface ------------------------------------------------------
def _init():
    k = Kalman1D(0.0, 0.0, 0.01, 0.5, 1.0)
    p, v = k.state()
    return abs(p - 0.0) < 1e-9 and abs(v - 0.0) < 1e-9

def _cov_2x2():
    k = Kalman1D(0.0, 0.0, 0.01, 0.5, 1.0)
    cov = k.covariance()
    return len(cov) == 2 and len(cov[0]) == 2 and len(cov[1]) == 2

chk("init", _init)
chk("cov_2x2", _cov_2x2)

# --- Test 2: convergence (true velocity 1.0 m/s, noisy measurements) --------
def _run_converge():
    k = Kalman1D(0.0, 0.0, 0.01, 0.5, 1.0)
    true_v = 1.0
    for step in range(1, 51):
        k.predict()
        z = step * true_v + random.gauss(0, 0.7)
        k.update(z)
    return k.state()

_cstate = {}
def _converge_pos():
    p, v = _run_converge()
    _cstate["p"], _cstate["v"] = p, v
    return abs(p - 50.0) < 5.0

def _converge_vel():
    if "v" in _cstate:
        v = _cstate["v"]
    else:
        _, v = _run_converge()
    return abs(v - 1.0) < 0.3

chk("converge_pos", _converge_pos)
chk("converge_vel", _converge_vel)

# --- Test 3: predict-only behaviour -----------------------------------------
def _predict_advances():
    k = Kalman1D(0.0, 1.0, 0.01, 0.5, 1.0)
    k.predict(); k.predict(); k.predict()
    p1, _ = k.state()
    return abs(p1 - 3.0) < 1e-6  # 3 steps * velocity 1

def _predict_grows_cov():
    k = Kalman1D(0.0, 1.0, 0.01, 0.5, 1.0)
    cov0 = k.covariance()
    k.predict(); k.predict(); k.predict()
    cov1 = k.covariance()
    return cov1[0][0] > cov0[0][0]

chk("predict_advances", _predict_advances)
chk("predict_grows_cov", _predict_grows_cov)
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    # Only honour declared behavioral checks; ignore stray output.
    if [[ -n "${BWEIGHT[$name]:-}" ]]; then
      BPASS[$name]="$pass"
      BNOTE[$name]="$note"
    fi
  done < <(echo "$RES")
fi

# Emit EVERY declared behavioral check exactly once - constant denominator.
for n in "${BNAMES[@]}"; do
  add "$n" "${BPASS[$n]}" "${BWEIGHT[$n]}" "${BNOTE[$n]}"
done

# ----------------------------------------------------------------------------
# Emit JSON. EVERYTHING above went to stderr; only this block hits stdout.
# ----------------------------------------------------------------------------
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
