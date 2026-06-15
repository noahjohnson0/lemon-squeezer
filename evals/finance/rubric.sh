#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  # sanitize note: strip backslashes, replace double-quotes with single,
  # collapse tabs/newlines to spaces (tab is our field separator)
  note="${note//\\/ }"
  note="${note//\"/\'}"
  note="${note//$'\t'/ }"
  note="${note//$'\n'/ }"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/finance.py"
add "file:finance.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

# Compile check: 1 only if the file exists AND compiles.
compiles=0
if [[ -f "$T" ]]; then
  if python3 -m py_compile "$T" 2>/dev/null; then compiles=1; fi
fi
add "compiles" "$compiles" 5

# Behavioral block. The python ALWAYS prints one line per declared check via
# chk(), regardless of import errors or per-case exceptions, so the set of
# emitted check NAMES is constant -> constant denominator. The FIRST emitted
# line is always "imports <1|0>".
RES=$(cd "$WS" && gtimeout 15 python3 - <<'PY' 2>/dev/null
import sys

ok = True
try:
    from finance import mortgage_payment, amortization_table, npv, irr
except Exception as e:
    sys.stderr.write("IMPORT_ERR %r\n" % (e,))
    ok = False

print("imports", 1 if ok else 0)

def near(a, b, tol):
    try:
        return abs(float(a) - float(b)) < tol
    except Exception:
        return False

def chk(name, fn):
    # ALWAYS emit a line for this check. Import failure or any exception in the
    # case scores 0 but never aborts the rest and never skips the line.
    if not ok:
        print(name, 0, "import-failed")
        return
    try:
        passed, note = fn()
        print(name, 1 if passed else 0, note)
    except Exception as ex:
        msg = repr(ex)[:50]
        print(name, 0, "EXC", msg)

# --- Mortgage payment ---
chk("mp_300k_6_30",   lambda: (near(mortgage_payment(300000, 0.06, 30), 1798.65, 0.05),
                               "got %r" % round(mortgage_payment(300000, 0.06, 30), 4)))
chk("mp_500k_4p5_15", lambda: (near(mortgage_payment(500000, 0.045, 15), 3824.97, 0.10),
                               "got %r" % round(mortgage_payment(500000, 0.045, 15), 4)))
chk("mp_100k_5_30",   lambda: (near(mortgage_payment(100000, 0.05, 30), 536.82, 0.05),
                               "got %r" % round(mortgage_payment(100000, 0.05, 30), 4)))

# --- Amortization ---
# Build the table once; each sub-check is independent so one bad key cannot
# vanish the others.
_amort = {}
def _build_amort():
    if "table" not in _amort:
        _amort["table"] = amortization_table(100000, 0.05, 30)
    return _amort["table"]

def _amort_len():
    t = _build_amort()
    return (len(t) == 360, "got %r" % len(t))

def _amort_r1p():
    t = _build_amort()
    v = t[0].get("payment")
    return (near(v, 536.82, 0.05), "got %r" % (v,))

def _amort_r1i():
    t = _build_amort()
    v = t[0].get("interest")
    return (near(v, 416.6667, 0.10), "got %r" % (v,))

def _amort_r1pr():
    t = _build_amort()
    v = t[0].get("principal")
    return (near(v, 120.15, 0.10), "got %r" % (v,))

def _amort_final():
    t = _build_amort()
    v = t[-1].get("balance")
    return (near(v, 0.0, 0.05), "got %r" % (v,))

chk("amort_len",            _amort_len)
chk("amort_row1_payment",   _amort_r1p)
chk("amort_row1_interest",  _amort_r1i)
chk("amort_row1_principal", _amort_r1pr)
chk("amort_final_zero",     _amort_final)

# --- NPV ---
chk("npv_basic", lambda: (near(npv(0.10, [-1000, 200, 300, 400, 500]), 71.78, 0.5),
                          "got %r" % round(npv(0.10, [-1000, 200, 300, 400, 500]), 4)))
chk("npv_zero",  lambda: (near(npv(0.0, [-100, 50, 50]), 0.0, 0.01),
                          "got %r" % round(npv(0.0, [-100, 50, 50]), 4)))

# --- IRR ---
def _irr_basic():
    r = irr([-1000, 200, 300, 400, 500])
    return (r is not None and near(r, 0.1280, 0.01), "got %r" % (r,))

def _irr_simple():
    r = irr([-100, 110])
    return (r is not None and near(r, 0.10, 0.001), "got %r" % (r,))

chk("irr_basic",  _irr_basic)
chk("irr_simple", _irr_simple)
PY
)
# Dump raw behavioral output to stderr for debugging (never stdout).
echo "$RES" >&2

# Weights per check name. The set of names below is the FIXED contract; the
# python above emits exactly these (plus "imports"), one line each, always.
weight_for() { case "$1" in
  imports)                 echo 8;;
  mp_*)                    echo 5;;
  amort_len)               echo 5;;
  amort_row1_payment)      echo 6;;
  amort_row1_interest)     echo 6;;
  amort_row1_principal)    echo 6;;
  amort_final_zero)        echo 8;;
  npv_basic)               echo 8;;
  npv_zero)                echo 4;;
  irr_basic)               echo 12;;
  irr_simple)              echo 5;;
  *)                       echo 3;;
esac; }

# The canonical, ALWAYS-scored behavioral checks. We iterate THIS list (not the
# emitted lines) so the denominator is constant: a name the python failed to
# emit (e.g. the whole block timed out / crashed) is scored 0, never dropped.
behavioral_names="imports mp_300k_6_30 mp_500k_4p5_15 mp_100k_5_30 \
amort_len amort_row1_payment amort_row1_interest amort_row1_principal amort_final_zero \
npv_basic npv_zero irr_basic irr_simple"

for name in $behavioral_names; do
  # find the emitted line for this name: "<name> <pass> [note...]"
  line=$(printf '%s\n' "$RES" | awk -v n="$name" '$1==n {print; exit}')
  if [[ -z "$line" ]]; then
    add "$name" 0 "$(weight_for "$name")" "no-output"
  else
    pass=$(printf '%s\n' "$line" | awk '{print $2}')
    note=$(printf '%s\n' "$line" | cut -d' ' -f3-)
    add "$name" "$pass" "$(weight_for "$name")" "$note"
  fi
done

# emit
total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in "${checks[@]}"; do
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
