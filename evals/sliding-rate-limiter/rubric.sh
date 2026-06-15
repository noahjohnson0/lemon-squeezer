#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks

# ---------------------------------------------------------------------------
# Sanitize notes so the emitted JSON stays valid: notes flow into a JSON
# string via printf %s, so strip backslashes (invalid \-escapes from repr())
# and replace double-quotes (they terminate the JSON string).
# ---------------------------------------------------------------------------
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

# Portable timeout: prefer gtimeout (macOS coreutils) then timeout (Linux/MSYS).
TO="$(command -v gtimeout || command -v timeout)"

# ---------------------------------------------------------------------------
# Constant-denominator design.
#
# Every declared check below is ALWAYS added exactly once (pass=1 or pass=0),
# no matter how broken the submission is. The behavioral checks come from a
# python probe whose chk() ALWAYS prints one line per declared check even on
# import error or per-case exception. Bash overlays the probe output onto a
# pre-seeded all-zero scaffold, so the weight set is identical for an empty
# stub, a non-importing file, a partial impl, and a correct one.
# ---------------------------------------------------------------------------

# name -> weight. Cheap checks are lightly weighted; the hard edge cases and
# the performance bound carry most of the score.
BEHAV_NAMES=(
  basics_under_cap
  basics_at_cap
  per_key_isolation
  no_double_burst
  boundary_exact_out
  boundary_just_in
  denied_no_count
  equal_timestamps
  eviction_recovers
  memory_bounded
  invalid_max_events
  invalid_window
)
declare -A BW
BW[basics_under_cap]=6
BW[basics_at_cap]=6
BW[per_key_isolation]=8
BW[no_double_burst]=12
BW[boundary_exact_out]=12
BW[boundary_just_in]=10
BW[denied_no_count]=12
BW[equal_timestamps]=8
BW[eviction_recovers]=8
BW[memory_bounded]=12
BW[invalid_max_events]=6
BW[invalid_window]=6
PERF_W=14

T="$WS/limiter.py"
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:limiter.py" "$file_ok" 3

compile_ok=0
if [[ "$file_ok" == "1" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && compile_ok=1
fi
add "compiles" "$compile_ok" 3

# Static anti-cheat: the limiter must not read the real clock. Only meaningful
# if there is an actual file; gated below on import success too.
realclock=0
if [[ "$file_ok" == "1" ]]; then
  if grep -qE 'time\.time|time\.monotonic|time\.perf_counter|datetime\.now|datetime\.utcnow|time\.process_time' "$T"; then
    realclock=1
  fi
fi

# ---------------------------------------------------------------------------
# Behavioral probe. Never sys.exit()s; chk() always emits a line.
# All diagnostics go to stderr. Time is passed in (no real clock used here).
# ---------------------------------------------------------------------------
RES=""
if [[ "$file_ok" == "1" && -n "$TO" ]]; then
  RES=$(cd "$WS" && "$TO" 15 python3 - <<'PY' 2>/dev/null
import sys

ok = True
try:
    from limiter import RateLimiter
except Exception as e:
    print("IMPORT_ERR", repr(e)[:100], file=sys.stderr)
    ok = False

def emit(name, p, note=""):
    note = str(note).replace("\\", "").replace('"', "'").replace("\n", " ").replace("\t", " ")
    if note:
        print(name, 1 if p else 0, note)
    else:
        print(name, 1 if p else 0)

def chk(name, fn):
    if not ok:
        emit(name, 0, "noimport")
        return
    try:
        emit(name, 1 if fn() else 0)
    except Exception as ex:
        emit(name, 0, repr(ex)[:50])

emit("imports", ok)

# ---- basic happy path: under the cap everything is allowed -------------
def t_basics_under_cap():
    rl = RateLimiter(5, 10.0)
    return all(rl.allow("a", float(i)) for i in range(5))
chk("basics_under_cap", t_basics_under_cap)

# ---- at the cap the (max+1)-th in-window event is denied ---------------
def t_basics_at_cap():
    rl = RateLimiter(3, 10.0)
    res = [rl.allow("a", 0.0), rl.allow("a", 1.0), rl.allow("a", 2.0), rl.allow("a", 3.0)]
    return res == [True, True, True, False]
chk("basics_at_cap", t_basics_at_cap)

# ---- per-key isolation: one key at its cap must not block another ------
def t_per_key_isolation():
    rl = RateLimiter(2, 10.0)
    rl.allow("a", 0.0); rl.allow("a", 1.0)
    blocked_a = not rl.allow("a", 2.0)        # a is full
    fresh_b = rl.allow("b", 2.0) and rl.allow("b", 3.0)  # b independent
    blocked_b = not rl.allow("b", 4.0)
    return blocked_a and fresh_b and blocked_b
chk("per_key_isolation", t_per_key_isolation)

# ---- THE sliding-window discriminator: no 2x burst across a boundary ---
# Fixed-window wrongly allows all 10; sliding must deny the straddling ones.
def t_no_double_burst():
    rl = RateLimiter(5, 10.0)
    first = [rl.allow("a", t) for t in (0.0, 0.1, 0.2, 0.3, 0.4)]   # 5 allowed
    # all still inside the window at t=9.x -> these must be DENIED
    second = [rl.allow("a", t) for t in (9.5, 9.6, 9.7, 9.8, 9.9)]
    return all(first) and not any(second)
chk("no_double_burst", t_no_double_burst)

# ---- boundary exact: an event of age EXACTLY window is OUT of window ----
# Window=(now-w, now]; the event at age==w must be dropped, freeing a slot.
def t_boundary_exact_out():
    rl = RateLimiter(1, 10.0)
    a1 = rl.allow("a", 0.0)        # allowed
    # at now=10.0 the prior event has age exactly 10 -> dropped -> allowed
    a2 = rl.allow("a", 10.0)
    return a1 and a2
chk("boundary_exact_out", t_boundary_exact_out)

# ---- boundary just inside: age just under window is STILL counted -------
def t_boundary_just_in():
    rl = RateLimiter(1, 10.0)
    a1 = rl.allow("a", 0.0)            # allowed
    a2 = rl.allow("a", 9.999)         # age < 10 -> still in window -> denied
    return a1 and (a2 is False)
chk("boundary_just_in", t_boundary_just_in)

# ---- denied events must NOT be recorded --------------------------------
# A rejected allow must not occupy a slot or push out a later legit event.
def t_denied_no_count():
    rl = RateLimiter(1, 10.0)
    rl.allow("a", 0.0)                 # allowed, fills the single slot
    d1 = not rl.allow("a", 1.0)        # denied (must NOT be stored)
    d2 = not rl.allow("a", 2.0)        # denied
    # the original event ages out at now=10.0; if denied events were stored,
    # one of them (at t=1 or t=2) would still be in-window and block this.
    ok10 = rl.allow("a", 10.0)
    return d1 and d2 and ok10
chk("denied_no_count", t_denied_no_count)

# ---- multiple events at the SAME timestamp each consume a slot ----------
def t_equal_timestamps():
    rl = RateLimiter(3, 10.0)
    r = [rl.allow("a", 5.0) for _ in range(4)]   # 3 allowed, 4th denied
    return r == [True, True, True, False]
chk("equal_timestamps", t_equal_timestamps)

# ---- eviction lets a saturated key recover after the window passes ------
def t_eviction_recovers():
    rl = RateLimiter(2, 10.0)
    rl.allow("a", 0.0); rl.allow("a", 1.0)
    blocked = not rl.allow("a", 5.0)             # full
    # both prior events aged out by now=12 -> 2 fresh allows succeed
    recover = rl.allow("a", 12.0) and rl.allow("a", 12.5)
    return blocked and recover
chk("eviction_recovers", t_eviction_recovers)

# ---- memory bounded: stored per-key timestamps never exceed max_events --
# Drive far more events than the cap across a moving window; the retained
# in-window set must stay <= max_events. We probe internal storage by size.
def _stored_len(rl, key):
    # find the per-key container without assuming an attribute name
    import collections
    best = None
    for attr in vars(rl).values():
        if isinstance(attr, dict) and key in attr:
            v = attr[key]
            try:
                return len(v)
            except TypeError:
                pass
    # fall back: scan any dict-of-sequences for the key
    for attr in vars(rl).values():
        if isinstance(attr, dict):
            for v in attr.values():
                try:
                    best = len(v) if best is None else max(best, len(v))
                except TypeError:
                    pass
    return best if best is not None else 0

def t_memory_bounded():
    rl = RateLimiter(5, 10.0)
    # 2000 events spaced 0.1s apart -> only ~5 are ever in-window at once.
    for i in range(2000):
        rl.allow("a", i * 0.1)
    n = _stored_len(rl, "a")
    # a never-evicting impl would store ~2000; a correct one keeps <= max.
    return n is not None and n <= 5
chk("memory_bounded", t_memory_bounded)

# ---- validation: bad args raise ValueError -----------------------------
def t_invalid_max_events():
    bad = (0, -1)
    for v in bad:
        try:
            RateLimiter(v, 10.0)
            return False
        except ValueError:
            pass
    return True
chk("invalid_max_events", t_invalid_max_events)

def t_invalid_window():
    for v in (0, -5.0):
        try:
            RateLimiter(5, v)
            return False
        except ValueError:
            pass
    return True
chk("invalid_window", t_invalid_window)
PY
)
fi

# Dump probe output to stderr only (never stdout).
echo "$RES" >&2

# ---------------------------------------------------------------------------
# Performance probe (isolated process, separately timed). A correct
# amortized-O(1) eviction finishes ~200k calls in well under a second; an
# O(n)-rescan-per-call impl that never evicts is ~200k^2/2 ~ 2e10 ops and
# blows this dedicated short timeout. Isolating it means a perf timeout zeroes
# ONLY perf_amortized, never the correctness checks above.
PERF=""
if [[ "$file_ok" == "1" && -n "$TO" ]]; then
  PERF=$(cd "$WS" && "$TO" 5 python3 - <<'PY' 2>/dev/null
try:
    from limiter import RateLimiter
    rl = RateLimiter(3, 1.0)
    N = 200000
    # step 0.5s: at most ~2 events in the 1.0s window, so a correct limiter
    # does O(1) work per call and stays tiny in memory.
    t = 0.0
    for _ in range(N):
        rl.allow("a", t)
        t += 0.5
    print("perf_amortized", 1)
except Exception as ex:
    print("perf_amortized", 0, repr(ex)[:50])
PY
)
fi
echo "$PERF" >&2
perf_pass=0; perf_note="timeout or no output"
if printf '%s\n' "$PERF" | grep -qE '^perf_amortized[[:space:]]+1'; then
  perf_pass=1; perf_note=""
elif printf '%s\n' "$PERF" | grep -qE '^perf_amortized[[:space:]]+0'; then
  perf_note="$(printf '%s' "$PERF" | sed -n 's/^perf_amortized 0 //p')"
fi

# Derive import success from the emitted "imports" line.
import_ok=0
if printf '%s\n' "$RES" | grep -qE '^imports[[:space:]]+1'; then
  import_ok=1
fi

# no_real_clock: credited only for an importable, real solution so a stub that
# merely lacks a time import can't earn it for free.
if [[ "$import_ok" == "1" && "$file_ok" == "1" ]]; then
  if [[ "$realclock" == "1" ]]; then
    add "no_real_clock" 0 6 "reads real clock"
  else
    add "no_real_clock" 1 6
  fi
else
  add "no_real_clock" 0 6 "no importable solution"
fi

# Pre-seed scaffold (imports + every behavioral check at pass=0) so the
# denominator is constant. Overlay the probe output.
declare -A PASS NOTE
PASS[imports]=0; NOTE[imports]=""
for n in "${BEHAV_NAMES[@]}"; do PASS[$n]=0; NOTE[$n]=""; done

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  [[ "$name" == "IMPORT_ERR" ]] && continue
  if [[ -v "PASS[$name]" ]]; then
    PASS[$name]="$pass"
    NOTE[$name]="$note"
  fi
done < <(printf '%s\n' "$RES")

# imports first (explicit penalty for a non-importing file), then behaviors.
add "imports" "${PASS[imports]}" 4 "${NOTE[imports]}"
for n in "${BEHAV_NAMES[@]}"; do
  add "$n" "${PASS[$n]}" "${BW[$n]}" "${NOTE[$n]}"
done

# Performance check from the isolated probe (timeout there => pass=0 here only).
add "perf_amortized" "$perf_pass" "$PERF_W" "$perf_note"

# ---------------------------------------------------------------------------
# Emit score JSON. FINAL stdout must be ONLY this object.
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
