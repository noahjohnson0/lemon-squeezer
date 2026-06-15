#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  # sanitize: notes must not contain backslashes or double-quotes (they break the JSON)
  note=$(printf '%s' "$note" | tr -d '\\' | tr '"' "'")
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

# ---------------------------------------------------------------------------
# CONSTANT-DENOMINATOR DESIGN
# Every check below is ALWAYS scored (pass=1 or pass=0), no matter how broken
# the submission is. The python block ALWAYS prints exactly one line per
# behavioral check (even on import failure or per-case exception), and the bash
# loop scores the FULL declared check list by looking up each name in that
# output (defaulting to 0 when absent). The denominator never changes.
# ---------------------------------------------------------------------------

# Declared behavioral checks and their weights (name:weight). This list is the
# single source of truth for the behavioral denominator.
BEHAV=(
  "imports:8"
  "lr1:12" "lr2:12" "lr3:12"
  "ci1:12" "ci2:12"
  "ci_n1_raises:10"
)

T="$WS/stats.py"
add "file:stats.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

# Static "compiles" check is independent of import success.
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
else
  add "compiles" 0 5
fi

# Run the behavioral probe. It ALWAYS emits one "name pass [note]" line per
# declared behavioral check; import failure -> all behavioral checks pass=0,
# but they are still emitted so nothing vanishes from the denominator.
if [[ -f "$T" ]]; then
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys

ok = True
try:
    from stats import linreg, mean_ci95
except Exception as e:
    print("IMPORT_ERR", repr(e), file=sys.stderr)
    ok = False

# imports check: directly penalize a non-importing file.
print("imports", 1 if ok else 0)

def near(a, b, tol=1e-3):
    try:
        return abs(float(a) - float(b)) < tol
    except Exception:
        return False

def chk(name, fn):
    # ALWAYS prints exactly one line for this check.
    if not ok:
        print(name, 0, "import failed")
        return
    try:
        passed, note = fn()
        print(name, 1 if passed else 0, note)
    except Exception as ex:
        print(name, 0, repr(ex)[:60])

# linreg cases
LR = [
    ([1, 2, 3, 4, 5], [2, 4, 5, 4, 5], (0.6, 2.2, 0.6)),
    ([0, 1, 2, 3], [1, 3, 5, 7], (2.0, 1.0, 1.0)),
    ([1, 2, 3], [3, 2, 1], (-1.0, 4.0, 1.0)),
]
def make_lr(x, y, s, b, r2):
    def run():
        gs, gb, gr2 = linreg(x, y)
        passed = near(gs, s) and near(gb, b) and near(gr2, r2)
        return passed, "got=(%.3f,%.3f,%.3f) want=(%s,%s,%s)" % (gs, gb, gr2, s, b, r2)
    return run
for i, (x, y, (s, b, r2)) in enumerate(LR, 1):
    chk("lr%d" % i, make_lr(x, y, s, b, r2))

# mean_ci95 cases
CI = [
    ([5.1, 4.9, 5.0, 5.2, 4.8, 5.1, 5.0, 4.9, 5.0, 5.0], 5.0, (4.917, 5.083)),
    ([10, 12, 9, 11, 13], 11.0, (9.037, 12.963)),
]
def make_ci(d, m, lo, hi):
    def run():
        gm, glo, ghi = mean_ci95(d)
        passed = near(gm, m, 1e-2) and near(glo, lo, 5e-2) and near(ghi, hi, 5e-2)
        return passed, "got=(%.3f,%.3f,%.3f) want=(%s,%.3f,%.3f)" % (gm, glo, ghi, m, lo, hi)
    return run
for i, (d, m, (lo, hi)) in enumerate(CI, 1):
    chk("ci%d" % i, make_ci(d, m, lo, hi))

# n=1 must raise ValueError
def ci_n1_raises():
    try:
        mean_ci95([42.0])
        return False, "no raise"
    except ValueError:
        return True, "raised ValueError"
    except Exception as ex:
        return False, ("wrong exc " + repr(ex))[:50]
chk("ci_n1_raises", ci_n1_raises)
PY
)
else
  RES=""
fi
echo "$RES" >&2

# Score the FULL declared behavioral check list. For each declared check, look
# up its emitted pass value (default 0 if the line is missing for any reason).
# This guarantees a constant denominator across stub / import-error / partial /
# correct submissions.
for spec in "${BEHAV[@]}"; do
  name="${spec%%:*}"
  w="${spec##*:}"
  line=$(echo "$RES" | awk -v n="$name" '$1==n {print; exit}')
  if [[ -n "$line" ]]; then
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
  else
    pass=0
    note="check not emitted"
  fi
  add "$name" "$pass" "$w" "$note"
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
