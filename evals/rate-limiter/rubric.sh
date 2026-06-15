#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  # sanitize note: drop backslashes and double-quotes (they break the JSON)
  note="${note//\\/}"
  note="${note//\"/\'}"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

# ---------------------------------------------------------------------------
# Constant-denominator rubric.
#
# Every declared check is ALWAYS added exactly once, as pass=1 or pass=0, no
# matter how broken the submission is (missing file, import error, exception
# mid-test). The behavioral checks come from a python block whose helper
# chk() ALWAYS prints a line; bash then layers each emitted line onto a
# pre-seeded all-zero scaffold so the weight set is invariant.
# ---------------------------------------------------------------------------

# Canonical behavioral checks (name -> always present). Order is stable.
BEHAV=(starts_full refill_works capped_capacity cost_over_capacity invalid_cap invalid_rate failed_no_consume)
BW=12  # weight per behavioral check

T="$WS/ratelimit.py"
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:ratelimit.py" "$file_ok" 5

compiles_ok=0
if [[ "$file_ok" == "1" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && compiles_ok=1
fi
add "compiles" "$compiles_ok" 5

# Run the behavioral probe. It NEVER sys.exit()s on import error; chk() always
# emits a line for every case, and an "imports" line reflects the import flag.
RES=""
if [[ "$file_ok" == "1" ]]; then
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>>/dev/stderr
import sys

def emit(name, p, note=""):
    # one space-separated line: name pass [note...]; never raises
    if note:
        print(name, 1 if p else 0, note)
    else:
        print(name, 1 if p else 0)

ok = True
try:
    from ratelimit import TokenBucket
except Exception as e:
    print("IMPORT_ERR", repr(e)[:120], file=sys.stderr)
    ok = False

emit("imports", ok)

def chk(name, fn):
    if not ok:
        emit(name, 0, "noimport")
        return
    try:
        emit(name, 1 if fn() else 0)
    except Exception as ex:
        emit(name, 0, repr(ex)[:50])

# Manual clock to avoid wall-clock flakiness.
clock = [0.0]
def now(): return clock[0]

# Test 1: starts full -> first 5 allow(1) succeed, 6th fails
def t_starts_full():
    clock[0] = 0.0
    b = TokenBucket(5, 1.0, now_fn=now)
    return all(b.allow(1) for _ in range(5)) and not b.allow(1)
chk("starts_full", t_starts_full)

# Test 2: refill rate works (capped at capacity)
def t_refill():
    clock[0] = 0.0
    b2 = TokenBucket(10, 2.0, now_fn=now)
    for _ in range(10): b2.allow(1)
    clock[0] = 5.0  # 5s -> 10 tokens refilled, capped at 10
    return b2.allow(10) and not b2.allow(1)
chk("refill_works", t_refill)

# Test 3: capped at capacity after long idle
def t_capped():
    clock[0] = 0.0
    b3 = TokenBucket(3, 1.0, now_fn=now)
    b3.allow(3)        # drain
    clock[0] = 100.0   # very long idle
    return abs(b3.tokens() - 3) < 0.001
chk("capped_capacity", t_capped)

# Test 4: cost > capacity always fails
def t_cost_over():
    clock[0] = 0.0
    b4 = TokenBucket(5, 1.0, now_fn=now)
    return not b4.allow(10)
chk("cost_over_capacity", t_cost_over)

# Test 5a: invalid capacity raises ValueError
def t_invalid_cap():
    try:
        TokenBucket(0, 1.0)
        return False
    except ValueError:
        return True
chk("invalid_cap", t_invalid_cap)

# Test 5b: invalid rate raises ValueError
def t_invalid_rate():
    try:
        TokenBucket(5, -1.0)
        return False
    except ValueError:
        return True
chk("invalid_rate", t_invalid_rate)

# Test 6: failed allow does NOT consume
def t_failed_no_consume():
    clock[0] = 0.0
    b5 = TokenBucket(2, 1.0, now_fn=now)
    b5.allow(2)                # drain
    denied = not b5.allow(1)   # nothing left -> deny, must not go negative
    clock[0] = 0.5             # 0.5s -> 0.5 tokens, still < 1
    denied2 = not b5.allow(1)
    return denied and denied2
chk("failed_no_consume", t_failed_no_consume)
PY
)
fi

# Dump the raw probe output to stderr for debugging (never to stdout).
echo "$RES" >&2

# Pre-seed a scaffold: imports + every behavioral check at pass=0. This makes
# the denominator constant. Parse the probe output and FLIP entries that the
# probe reported, overlaying pass/note onto the scaffold.
declare -A PASS NOTE
PASS[imports]=0; NOTE[imports]=""
for n in "${BEHAV[@]}"; do PASS[$n]=0; NOTE[$n]=""; done

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(echo "$line" | awk '{print $1}')
  pass=$(echo "$line" | awk '{print $2}')
  note=$(echo "$line" | cut -d' ' -f3-)
  [[ "$name" == "IMPORT_ERR" ]] && continue
  # only accept names we declared (ignore stray output)
  if [[ -v "PASS[$name]" ]]; then
    PASS[$name]="$pass"
    NOTE[$name]="$note"
  fi
done < <(echo "$RES")

# Emit imports first (explicit penalty for a non-importing file), then behav.
add "imports" "${PASS[imports]}" 6 "${NOTE[imports]}"
for n in "${BEHAV[@]}"; do
  add "$n" "${PASS[$n]}" "$BW" "${NOTE[$n]}"
done

# ---------------------------------------------------------------------------
# Emit the score JSON. The FINAL stdout line(s) must be ONLY this object.
# ---------------------------------------------------------------------------
total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in ${checks[@]+"${checks[@]}"}; do
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
