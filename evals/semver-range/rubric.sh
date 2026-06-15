#!/usr/bin/env bash
# Rubric for the "semver-range" eval. Hardened per CLAUDE.md rubric gotchas:
#  * CONSTANT DENOMINATOR: every check is declared up-front and ALWAYS scored
#    exactly once. The python probe emits one line per declared behavioral
#    check whether or not the import works; any check the probe fails to emit
#    (crash/timeout) is swept in as 0 below.
#  * JSON-SAFE: all diagnostics go to stderr; notes are sanitized (no
#    backslashes, no double-quotes) before entering the hand-rolled JSON.
#  * HERMETIC/DETERMINISTIC: no network, no sockets, no wall-clock dependence
#    in the correctness checks; the single perf check uses a generous bound a
#    correct linear implementation clears easily and a quadratic one misses.
#  * PORTABLE TIMEOUT: gtimeout || timeout.
set -u
WS="${1:?workspace}"
declare -a checks
declare -A seen

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
  seen["$n"]=1
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

# Portable timeout selection.
TO="$(command -v gtimeout || command -v timeout)"

# ---------------------------------------------------------------------------
# Declared behavioral inventory + weights. EVERY name here is scored exactly
# once. Weights are concentrated on the HARD checks (prerelease precedence,
# range edge cases, npm prerelease gating, perf) so a happy-path-only naive
# solution lands well below a correct one, and a stub scores ~0.
# ---------------------------------------------------------------------------
# name weight  (kept in a parallel array so the sweep can backfill missing ones)
declare -A W=(
  [imports]=4
  # parse: happy path (light)
  [parse_basic]=2
  [parse_v_prefix]=2
  [parse_pre_split]=3
  [parse_numeric_id_int]=3
  [parse_build_ignored]=3
  # parse: rejection edge cases (heavy - naive regex misses these)
  [reject_short]=3
  [reject_leadzero_core]=4
  [reject_leadzero_preid]=4
  [reject_empty_pre]=3
  [reject_empty_build]=3
  [reject_bad_char]=3
  [accept_pre_zero]=3
  # compare: precedence (heavy on prerelease rules)
  [cmp_core]=2
  [cmp_pre_lt_release]=5
  [cmp_numeric_vs_alpha]=5
  [cmp_more_ids_wins]=5
  [cmp_numeric_order]=4
  [cmp_build_ignored]=4
  [cmp_spec_chain]=5
  # satisfies: sugar expansion (heavy on zero-component edges)
  [sat_caret_basic]=3
  [sat_caret_zero_minor]=5
  [sat_caret_zero_patch]=5
  [sat_caret_xrange]=4
  [sat_tilde_full]=3
  [sat_tilde_partial]=4
  [sat_tilde_major_only]=4
  [sat_hyphen_full]=3
  [sat_hyphen_partial_hi]=5
  [sat_hyphen_partial_lo]=4
  [sat_xrange]=3
  [sat_xrange_major]=3
  [sat_comparators]=3
  [sat_and]=3
  [sat_or]=4
  [sat_star]=3
  # satisfies: npm prerelease gating (the trickiest part - heavy)
  [sat_pre_gated_in]=6
  [sat_pre_gated_out]=6
  [sat_pre_star_excludes]=5
  [sat_pre_release_vs_pre_comp]=5
  # performance
  [perf]=10
)
# Stable ordering for the sweep / display.
ORDER=(imports
  parse_basic parse_v_prefix parse_pre_split parse_numeric_id_int parse_build_ignored
  reject_short reject_leadzero_core reject_leadzero_preid reject_empty_pre reject_empty_build reject_bad_char accept_pre_zero
  cmp_core cmp_pre_lt_release cmp_numeric_vs_alpha cmp_more_ids_wins cmp_numeric_order cmp_build_ignored cmp_spec_chain
  sat_caret_basic sat_caret_zero_minor sat_caret_zero_patch sat_caret_xrange
  sat_tilde_full sat_tilde_partial sat_tilde_major_only
  sat_hyphen_full sat_hyphen_partial_hi sat_hyphen_partial_lo
  sat_xrange sat_xrange_major sat_comparators sat_and sat_or sat_star
  sat_pre_gated_in sat_pre_gated_out sat_pre_star_excludes sat_pre_release_vs_pre_comp
  perf)

# --- static checks (always emitted) ---
T="$WS/semver.py"
add "file:semver.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 4
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 4 || add "compiles" 0 4
else
  add "compiles" 0 4
fi

# --- behavioral probe ---
# The python block NEVER exits early and NEVER lets one failing case abort the
# rest. chk() always prints exactly one line per declared name. The perf check
# is timed in-process with time.perf_counter() against a fixed workload (a
# correct O(1)-per-call matcher clears the budget with huge margin; an O(n^2)
# re-parse-everything implementation blows it). The whole probe is wrapped in a
# portable timeout as a backstop.
PYERR="$(mktemp 2>/dev/null || echo /tmp/semver_pyerr_$$)"
RES=$(cd "$WS" && "$TO" 20 python3 - <<'PY' 2>"$PYERR"
import sys, time

ok = True
try:
    from semver import parse, compare, satisfies
except Exception as e:
    print("imports", 0, "import failed:", repr(e)[:60])
    ok = False
else:
    print("imports", 1)

def chk(name, fn):
    if not ok:
        print(name, 0, "no import")
        return
    try:
        print(name, 1 if fn() else 0)
    except Exception as ex:
        print(name, 0, "ERR", repr(ex)[:50])

def raises(fn):
    try:
        fn()
    except ValueError:
        return True
    except Exception:
        return False
    return False

# ---- parse: happy path ----
chk("parse_basic", lambda: parse("1.2.3")[:3] == (1, 2, 3))
chk("parse_v_prefix", lambda: parse("v2.0.0")[:3] == (2, 0, 0))
chk("parse_pre_split", lambda: parse("1.0.0-alpha.1")[3] == ("alpha", 1))
chk("parse_numeric_id_int",
    lambda: parse("1.0.0-rc.0")[3] == ("rc", 0)
            and all(isinstance(x, int) for x in (parse("1.0.0-rc.0")[3][1],)))
chk("parse_build_ignored",
    lambda: parse("1.2.3+build.5")[:4] == (1, 2, 3, ())
            and parse("1.2.3+build.5")[4] == "build.5")

# ---- parse: rejection edges ----
chk("reject_short", lambda: raises(lambda: parse("1.2")) and raises(lambda: parse("1")))
chk("reject_leadzero_core",
    lambda: raises(lambda: parse("01.2.3"))
            and raises(lambda: parse("1.02.3"))
            and raises(lambda: parse("1.2.03")))
chk("reject_leadzero_preid",
    lambda: raises(lambda: parse("1.0.0-01"))
            and raises(lambda: parse("1.0.0-1.02")))
chk("reject_empty_pre", lambda: raises(lambda: parse("1.0.0-")))
chk("reject_empty_build", lambda: raises(lambda: parse("1.0.0+")))
chk("reject_bad_char",
    lambda: raises(lambda: parse("1.0.0-bet@"))
            and raises(lambda: parse("1.2.x")))  # non-numeric core component
# accept_pre_zero: '0' and 'rc.0' are valid numeric ids, '1.0.0-0' is valid
chk("accept_pre_zero",
    lambda: parse("1.0.0-0")[3] == (0,) and parse("1.0.0-alpha.0")[3] == ("alpha", 0))

# ---- compare: precedence ----
chk("cmp_core",
    lambda: compare("1.2.3", "1.2.4") == -1
            and compare("2.0.0", "1.9.9") == 1
            and compare("1.2.3", "1.2.3") == 0)
chk("cmp_pre_lt_release",
    lambda: compare("1.0.0-alpha", "1.0.0") == -1
            and compare("1.0.0", "1.0.0-alpha") == 1)
chk("cmp_numeric_vs_alpha",
    # numeric identifiers always have LOWER precedence than alphanumeric
    lambda: compare("1.0.0-1", "1.0.0-alpha") == -1
            and compare("1.0.0-alpha", "1.0.0-1") == 1)
chk("cmp_more_ids_wins",
    lambda: compare("1.0.0-alpha", "1.0.0-alpha.1") == -1
            and compare("1.0.0-alpha.1", "1.0.0-alpha.beta") == -1)
chk("cmp_numeric_order",
    lambda: compare("1.0.0-alpha.2", "1.0.0-alpha.10") == -1
            and compare("1.0.0-beta.11", "1.0.0-beta.2") == 1)
chk("cmp_build_ignored",
    lambda: compare("1.2.3+a", "1.2.3+b") == 0
            and compare("1.2.3-rc.1+x", "1.2.3-rc.1+y") == 0)
chk("cmp_spec_chain",
    # the canonical semver.org precedence chain
    lambda: [compare(a, b) for a, b in [
        ("1.0.0-alpha", "1.0.0-alpha.1"),
        ("1.0.0-alpha.1", "1.0.0-alpha.beta"),
        ("1.0.0-alpha.beta", "1.0.0-beta"),
        ("1.0.0-beta", "1.0.0-beta.2"),
        ("1.0.0-beta.2", "1.0.0-beta.11"),
        ("1.0.0-beta.11", "1.0.0-rc.1"),
        ("1.0.0-rc.1", "1.0.0"),
    ]] == [-1] * 7)

# ---- satisfies: caret ----
chk("sat_caret_basic",
    lambda: satisfies("1.2.3", "^1.2.3") and satisfies("1.9.9", "^1.2.3")
            and not satisfies("2.0.0", "^1.2.3") and not satisfies("1.2.2", "^1.2.3"))
chk("sat_caret_zero_minor",
    # ^0.2.3 := >=0.2.3 <0.3.0
    lambda: satisfies("0.2.9", "^0.2.3") and not satisfies("0.3.0", "^0.2.3")
            and not satisfies("0.2.2", "^0.2.3"))
chk("sat_caret_zero_patch",
    # ^0.0.3 := >=0.0.3 <0.0.4
    lambda: satisfies("0.0.3", "^0.0.3") and not satisfies("0.0.4", "^0.0.3")
            and not satisfies("0.1.0", "^0.0.3"))
chk("sat_caret_xrange",
    # ^1.x := >=1.0.0 <2.0.0 ; ^0.0.x := >=0.0.0 <0.1.0
    lambda: satisfies("1.5.0", "^1.x") and not satisfies("2.0.0", "^1.x")
            and satisfies("0.0.9", "^0.0.x") and not satisfies("0.1.0", "^0.0.x"))

# ---- satisfies: tilde ----
chk("sat_tilde_full",
    # ~1.2.3 := >=1.2.3 <1.3.0
    lambda: satisfies("1.2.9", "~1.2.3") and not satisfies("1.3.0", "~1.2.3")
            and not satisfies("1.2.2", "~1.2.3"))
chk("sat_tilde_partial",
    # ~1.2 := >=1.2.0 <1.3.0
    lambda: satisfies("1.2.0", "~1.2") and satisfies("1.2.9", "~1.2")
            and not satisfies("1.3.0", "~1.2"))
chk("sat_tilde_major_only",
    # ~1 := >=1.0.0 <2.0.0
    lambda: satisfies("1.0.0", "~1") and satisfies("1.9.9", "~1")
            and not satisfies("2.0.0", "~1"))

# ---- satisfies: hyphen ----
chk("sat_hyphen_full",
    lambda: satisfies("1.2.3", "1.2.3 - 2.3.4") and satisfies("2.3.4", "1.2.3 - 2.3.4")
            and not satisfies("2.3.5", "1.2.3 - 2.3.4")
            and not satisfies("1.2.2", "1.2.3 - 2.3.4"))
chk("sat_hyphen_partial_hi",
    # 1.2.3 - 2.3 := >=1.2.3 <2.4.0
    lambda: satisfies("2.3.9", "1.2.3 - 2.3") and not satisfies("2.4.0", "1.2.3 - 2.3"))
chk("sat_hyphen_partial_lo",
    # 1.2 - 2.3.4 := >=1.2.0 <=2.3.4
    lambda: satisfies("1.2.0", "1.2 - 2.3.4") and satisfies("2.3.4", "1.2 - 2.3.4")
            and not satisfies("1.1.9", "1.2 - 2.3.4"))

# ---- satisfies: x-ranges / comparators / and / or / star ----
chk("sat_xrange",
    # 1.2.x := >=1.2.0 <1.3.0
    lambda: satisfies("1.2.0", "1.2.x") and satisfies("1.2.7", "1.2.*")
            and not satisfies("1.3.0", "1.2.x"))
chk("sat_xrange_major",
    # 1.x := >=1.0.0 <2.0.0 ; bare '1' likewise
    lambda: satisfies("1.0.0", "1.x") and satisfies("1.9.9", "1")
            and not satisfies("2.0.0", "1.x"))
chk("sat_comparators",
    lambda: satisfies("1.2.3", ">=1.2.0") and not satisfies("1.1.9", ">=1.2.0")
            and satisfies("1.2.3", "<2.0.0") and not satisfies("2.0.0", "<2.0.0")
            and satisfies("1.2.3", "=1.2.3"))
chk("sat_and",
    lambda: satisfies("1.5.0", ">=1.2.0 <2.0.0")
            and not satisfies("2.0.1", ">=1.2.0 <2.0.0")
            and not satisfies("1.1.0", ">=1.2.0 <2.0.0"))
chk("sat_or",
    lambda: satisfies("1.0.0", "<1.0.0 || >=2.0.0") is False
            and satisfies("2.5.0", "<1.0.0 || >=2.0.0")
            and satisfies("0.9.0", "<1.0.0 || >=2.0.0"))
chk("sat_star",
    lambda: satisfies("9.9.9", "*") and satisfies("0.0.1", "") )

# ---- satisfies: npm prerelease gating ----
chk("sat_pre_gated_in",
    # 1.2.3-beta.2 satisfies a range whose lower bound shares 1.2.3 + has a pre
    lambda: satisfies("1.2.3-beta.2", ">=1.2.3-beta.1 <1.2.4")
            and satisfies("1.2.3-beta.2", ">=1.2.3-alpha"))
chk("sat_pre_gated_out",
    # 1.2.3-beta.2 does NOT satisfy a plain release range (no comparator pins
    # 1.2.3 with a prerelease tag)
    lambda: not satisfies("1.2.3-beta.2", ">=1.0.0 <2.0.0")
            and not satisfies("1.2.3-beta.2", "^1.0.0")
            and not satisfies("3.0.0-alpha", ">=1.2.3-beta.1 <2.0.0"))
chk("sat_pre_star_excludes",
    # wildcards / empty / '*' never match a prerelease version
    lambda: not satisfies("1.0.0-rc.1", "*")
            and not satisfies("1.0.0-rc.1", "")
            and not satisfies("1.0.0-rc.1", "1.x"))
chk("sat_pre_release_vs_pre_comp",
    # a NON-prerelease version compares to prerelease comparators normally
    lambda: satisfies("1.2.3", ">1.2.3-beta")
            and satisfies("1.2.3", ">=1.2.3-rc.1")
            and not satisfies("1.2.2", ">1.2.3-beta"))

# ---- performance ----
# Build a large workload: many satisfies() calls against a long ||-joined range
# and versions with long prerelease identifier lists. A correct implementation
# parses each input once per call (linear) and is trivially fast. A naive
# implementation that re-parses/re-expands quadratically, or compares
# prerelease lists with an accidental O(n^2), blows the budget.
def perf_ok():
    # OR range: 80 alternatives, satisfied via the FIRST set for 2.x.y and by
    # NONE for 130.0.0 (forces a full scan of the alternatives that miss).
    alts = " || ".join(f">={i}.0.0 <{i}.1.0" for i in range(3, 83))
    rng = ">=2.0.0 <3.0.0 || " + alts
    # Long prerelease identifier lists differing only at the LAST identifier:
    # a correct linear left-to-right compare is fast; an accidental O(n^2)
    # (re-slicing growing prefixes / re-joining strings) is ~5x slower and
    # blows the budget.
    long_a = "1.0.0-" + ".".join(["alpha"] * 1000 + ["1"])
    long_b = "1.0.0-" + ".".join(["alpha"] * 1000 + ["2"])
    t0 = time.perf_counter()
    acc = 0
    for k in range(1500):
        if satisfies("2.5.7", rng):
            acc += 1
        if not satisfies("130.0.0", rng):
            acc += 1
    for k in range(1500):
        if compare(long_a, long_b) == -1:
            acc += 1
    dt = time.perf_counter() - t0
    # correctness gate: the workload must also be ANSWERED correctly, else a
    # solution that "fast-returns wrong" can't farm the perf point.
    correct = (acc == 4500)
    return correct and (dt < 4.0)
chk("perf", perf_ok)
PY
)
PYRC=$?
{ echo "=== semver-range probe stdout ==="; echo "$RES";
  echo "=== probe stderr ==="; cat "$PYERR" 2>/dev/null;
  echo "=== probe rc=$PYRC ==="; } >&2
rm -f "$PYERR" 2>/dev/null

# Fold emitted behavioral lines in at their declared weight.
IMPORTS_PASS=0
IMPORTS_NOTE="probe emitted no imports line"
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  if [[ "$name" == "imports" ]]; then
    IMPORTS_PASS="$pass"; IMPORTS_NOTE="$note"
    continue
  fi
  w="${W[$name]:-}"
  [[ -z "$w" ]] && continue        # ignore unexpected names
  add "$name" "$pass" "$w" "$note"
done < <(printf '%s\n' "$RES")

# imports is its own scored check so a non-importing file is penalized directly.
add "imports" "$IMPORTS_PASS" "${W[imports]}" "$IMPORTS_NOTE"

# Safety net: any declared behavioral check the probe failed to emit
# (crash/timeout/kill) is scored 0 so the denominator stays CONSTANT.
for n in "${ORDER[@]}"; do
  [[ -n "${seen[$n]:-}" ]] || add "$n" 0 "${W[$n]}" "missing from probe output"
done

# --- emit score JSON (stdout ONLY) ---
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
