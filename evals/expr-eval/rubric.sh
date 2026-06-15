#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks

# Sanitize notes so the emitted JSON stays valid: drop backslashes and turn
# double-quotes into single-quotes (both break the hand-rolled JSON below),
# and flatten newlines/tabs.
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

# Portable timeout: gtimeout (coreutils on mac) or timeout (linux).
TO="$(command -v gtimeout || command -v timeout)"

T="$WS/expr.py"

# --- static checks (deliberately small weight) ---
# An empty stub that merely exists/compiles/doesn't import a parser must NOT be
# able to clear a passing score on static credit alone. Real points live in the
# behavioral + perf cases below.
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:expr.py" "$file_ok" 2

compile_ok=0
if [[ "$file_ok" == "1" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && compile_ok=1
fi
add "compiles" "$compile_ok" 2

# --- behavioral checks (ALWAYS emitted, one line per declared case) ---
# The python block never aborts: on import error it sets ok=False and chk()
# still prints "<name> 0", so the denominator is constant regardless of how
# broken the submission is. Perf checks live in their own timed block so a hang
# there cannot starve the correctness checks of their output.
RES=$("$TO" 30 env WS="$WS" python3 - <<'PY' 2>&1
import sys, os, math, threading
ws = os.environ["WS"]
sys.path.insert(0, ws)
sys.setrecursionlimit(100000)

ok = True
try:
    from expr import evaluate
except Exception as e:
    print("IMPORT_ERR", repr(e)[:80], file=sys.stderr)
    ok = False

def emit(name, passed, note=""):
    note = str(note).replace("\\", "").replace('"', "'").replace("\n", " ").replace("\t", " ")
    print(name, 1 if passed else 0, note)
    sys.stdout.flush()

# Per-call watchdog: run evaluate() in a daemon thread so a single hanging or
# infinite-looping case (the contract forbids hanging) fails ONLY that case
# instead of starving the whole batch. A timeout is reported as a sentinel so
# close()->wrong-value and raises()->no-raise both treat it correctly.
class _Timeout(Exception):
    pass

def _run(expr):
    box = {}
    def work():
        try:
            box["v"] = evaluate(expr)
        except Exception as ex:
            box["e"] = ex
    t = threading.Thread(target=work, daemon=True)
    t.start()
    t.join(2.0)
    if t.is_alive():
        raise _Timeout("hang")
    if "e" in box:
        raise box["e"]
    return box["v"]

def chk(name, fn):
    if not ok:
        emit(name, 0, "no_import")
        return
    try:
        emit(name, 1 if fn() else 0)
    except Exception as ex:
        emit(name, 0, repr(ex)[:50])

# import status as its own behavioral check
emit("imports", ok, "" if ok else "could not import evaluate")

TOL = 1e-9
def close(expr, expected):
    v = _run(expr)
    return isinstance(v, float) and abs(v - expected) <= TOL + 1e-9 * abs(expected)

# returns_float: the contract says evaluate -> float
chk("returns_float", lambda: isinstance(_run("1"), float))

# --- happy path (low value individually) ---
chk("hp_int",      lambda: close("42", 42.0))
chk("hp_add",      lambda: close("1 + 2", 3.0))
chk("hp_sub",      lambda: close("9 - 4", 5.0))
chk("hp_mul",      lambda: close("6 * 7", 42.0))
chk("hp_paren",    lambda: close("(2 + 3) * 4", 20.0))

# --- precedence: a naive left-to-right scan gets these WRONG ---
chk("prec_add_mul",   lambda: close("2 + 3 * 4", 14.0))
chk("prec_mul_add",   lambda: close("2 * 3 + 4", 10.0))
chk("prec_mixed",     lambda: close("2 + 3 * 4 - 5", 9.0))
chk("prec_div_add",   lambda: close("100 + 20 / 4", 105.0))
chk("prec_chain",     lambda: close("1 + 2 * 3 + 4 * 5", 27.0))
chk("prec_deep",      lambda: close("2 * 3 + 4 * 5 - 6 / 2", 23.0))

# --- left associativity (naive recursive descent that recurses right gets these wrong) ---
chk("assoc_sub",   lambda: close("10 - 3 - 2", 5.0))
chk("assoc_div",   lambda: close("100 / 5 / 2", 10.0))
chk("assoc_mix",   lambda: close("20 - 5 - 3 - 2", 10.0))
chk("assoc_divmul",lambda: close("64 / 4 / 2 * 3", 24.0))

# --- modulo: precedence == * and Python sign semantics ---
chk("mod_basic",     lambda: close("17 % 5", 2.0))
chk("mod_prec",      lambda: close("2 + 10 % 4", 4.0))
chk("mod_neg",       lambda: close("-7 % 3", 2.0))   # python: 2, not -1
chk("mod_float",     lambda: close("5.5 % 2", 1.5))
chk("mod_chain",     lambda: close("20 % 7 % 4", 2.0))  # left assoc: (20%7)%4 = 6%4 = 2

# --- unary minus composition ---
chk("un_lead",     lambda: close("-5", -5.0))
chk("un_add",      lambda: close("-2 + 3", 1.0))
chk("un_paren",    lambda: close("-(2 + 3)", -5.0))
chk("un_double",   lambda: close("--5", 5.0))
chk("un_after_op", lambda: close("2 - -3", 5.0))
chk("un_mul_neg",  lambda: close("-3 * -4", 12.0))
chk("un_prec",     lambda: close("-2 * 3 + 1", -5.0))  # (-2)*3+1 = -5, not -(2*3+1)

# --- floats / scientific notation ---
chk("flt_dec",     lambda: close("3.14 + 0.86", 4.0))
chk("flt_lead",    lambda: close(".5 + .5", 1.0))
chk("flt_trail",   lambda: close("2. * 3.", 6.0))
chk("sci_e",       lambda: close("1e3", 1000.0))
chk("sci_neg",     lambda: close("2.5e-2 * 4", 0.1))
chk("sci_plus",    lambda: close("1.2e+3 - 200", 1000.0))
chk("sci_expr",    lambda: close("1e2 + 5e1", 150.0))

# --- division is true division (not floor) ---
chk("truediv",     lambda: close("7 / 2", 3.5))
chk("truediv_neg", lambda: close("-7 / 2", -3.5))

# --- whitespace insensitivity ---
chk("ws_none",     lambda: close("1+2*3", 7.0))
chk("ws_pad",      lambda: close("  1 + 2 * 3  ", 7.0))
chk("ws_tabs",     lambda: close("1\t+\t2", 3.0))

# --- nesting ---
chk("nest_paren",  lambda: close("((1 + 2) * (3 + 4))", 21.0))
chk("nest_deep",   lambda: close("2 * (3 + (4 - (1 + 1)))", 10.0))

# --- error handling: MUST raise (not return wrong value / None / hang) ---
# A hang counts as a FAILURE (the contract forbids hanging), so a _Timeout must
# NOT be credited as "raised an error".
def raises(expr):
    try:
        _run(expr)
    except _Timeout:
        return False
    except Exception:
        return True
    return False

chk("err_empty",        lambda: raises(""))
chk("err_ws_only",      lambda: raises("   "))
chk("err_unbal_open",   lambda: raises("(1 + 2"))
chk("err_unbal_close",  lambda: raises("1 + 2)"))
chk("err_unbal_nest",   lambda: raises("(()"))
chk("err_empty_paren",  lambda: raises("()"))
chk("err_empty_paren2", lambda: raises("3 * ()"))
chk("err_trail_op",     lambda: raises("1 +"))
chk("err_lead_op",      lambda: raises("* 3"))
chk("err_double_op",    lambda: raises("1 + * 2"))
chk("err_two_nums",     lambda: raises("1 2"))
chk("err_num_paren",    lambda: raises("3 (4)"))
chk("err_divzero",      lambda: raises("1 / 0"))
chk("err_modzero",      lambda: raises("5 % 0"))
chk("err_garbage_op",   lambda: raises("1 $ 2"))
chk("err_letters",      lambda: raises("abc"))

# A correct evaluator must NOT raise on a hard-but-valid expression. This
# catches over-eager "raise on everything" stubs that would otherwise ace the
# error suite for free.
chk("valid_not_raise",  lambda: close("-(1 + 2) * 3 + 10 / 2 - 4 % 3", -5.0))
PY
)
rc=$?
echo "$RES" >&2

# --- performance checks (separate timed block) ---
# A correct O(n) parser finishes both in well under a second; a quadratic or
# exponential parser blows the per-process timeout and the check scores 0.
# We deliberately give a SHORT budget so naive O(n^2)/O(2^n) parsers fail.
PERF=$("$TO" 20 env WS="$WS" python3 - <<'PY' 2>&1
import sys, os, time, threading
ws = os.environ["WS"]
sys.path.insert(0, ws)
sys.setrecursionlimit(100000)
ok = True
try:
    from expr import evaluate
except Exception as e:
    print("IMPORT_ERR", repr(e)[:80], file=sys.stderr)
    ok = False

def emit(name, passed, note=""):
    note = str(note).replace("\\", "").replace('"', "'").replace("\n", " ").replace("\t", " ")
    print(name, 1 if passed else 0, note)
    sys.stdout.flush()

# Run each perf case in a daemon thread with a hard 4s wall. A quadratic parser
# that runs forever fails ONLY its own case (timeout -> 0) instead of starving
# the others, and the per-case internal dt<3.0 gate is the primary discriminator.
def run_perf(name, fn):
    box = {}
    def work():
        try:
            box["v"] = bool(fn())
        except Exception as ex:
            box["e"] = ex
    th = threading.Thread(target=work, daemon=True)
    th.start()
    th.join(4.0)
    if th.is_alive():
        emit(name, 0, "timeout >4s (quadratic?)")
    elif "e" in box:
        emit(name, 0, repr(box["e"])[:50])
    else:
        emit(name, box["v"])

# Long FLAT expression: 1+1+1+... (50000 terms). A tokenize-once, index-based
# O(n) parser finishes in ~0.1s; a parser that consumes tokens by slicing the
# front of a string/list (e.g. repeated pop(0) / s = s[k:]) is O(n^2) and blows
# the 3s budget. The value check also rules out a parser that simply gives up.
def perf_flat():
    n = 200000
    s = "+".join(["1"] * n)
    t0 = time.time()
    v = evaluate(s)
    dt = time.time() - t0
    return abs(v - float(n)) <= 1e-6 and dt < 3.0

# Long flat WITH precedence: every term is 2*3 = 6. A correct O(n) parser is
# instant and gets 6*n; a left-to-right scanner gets the WRONG value, and a
# quadratic parser blows the budget. Catches both failure modes at once.
def perf_mixed():
    n = 120000
    s = "+".join(["2*3"] * n)  # each term = 6
    t0 = time.time()
    v = evaluate(s)
    dt = time.time() - t0
    return abs(v - 6.0 * n) <= 1e-3 and dt < 3.0

# Moderately NESTED parens (correctness + linear-time). Depth is kept
# recursion-safe so a canonical recursive-descent reference does not overflow
# the C stack; the point here is that a correct parser handles real nesting at
# all and stays fast, not to probe stack limits.
def perf_nested():
    d = 400
    s = "(" * d + "1" + ")" * d
    t0 = time.time()
    v = evaluate(s)
    dt = time.time() - t0
    return abs(v - 1.0) <= 1e-6 and dt < 3.0

if not ok:
    emit("perf_flat", 0, "no_import")
    emit("perf_mixed", 0, "no_import")
    emit("perf_nested", 0, "no_import")
else:
    for nm, fn in (("perf_flat", perf_flat), ("perf_mixed", perf_mixed), ("perf_nested", perf_nested)):
        try:
            run_perf(nm, fn)
        except Exception as ex:
            emit(nm, 0, repr(ex)[:50])
PY
)
prc=$?
echo "$PERF" >&2

# --- static anti-cheat: must not use eval/exec/ast etc. Only credited when the
# file exists AND actually imports (so an empty stub can't game this for free). ---
import_ok=0
if printf '%s\n' "$RES" | grep -qE '^imports[[:space:]]+1'; then
  import_ok=1
fi
if [[ "$import_ok" == "1" && "$file_ok" == "1" ]]; then
  # Match the forbidden builtins ONLY as bare calls (not preceded by a dot, so
  # re.compile / self.eval are fine), plus ast.literal_eval and any ast import.
  if grep -qE '(^|[^.[:alnum:]_])(eval|exec|compile)[[:space:]]*\(|literal_eval|(^|[^.[:alnum:]_])import[[:space:]]+ast([[:space:]]|,|$)|from[[:space:]]+ast[[:space:]]+import' "$T"; then
    add "no_eval" 0 12 "uses eval/exec/compile/ast"
  else
    add "no_eval" 1 12
  fi
else
  add "no_eval" 0 12 "no importable solution"
fi

# --- fold emitted lines into a name->value map (so a mid-stream crash leaves
# the remaining declared checks at 0 rather than dropping them) ---
declare -A SEEN
fold() {
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    case "$line" in IMPORT_ERR*) continue;; esac
    local name pass note
    name=$(printf '%s' "$line" | awk '{print $1}')
    pass=$(printf '%s' "$line" | awk '{print $2}')
    note=$(printf '%s' "$line" | cut -d' ' -f3-)
    SEEN["$name"]="$pass	$note"
  done < <(printf '%s\n' "$1")
}
fold "$RES"
fold "$PERF"

emit_check() {
  local name="$1" weight="$2"
  if [[ -n "${SEEN[$name]+x}" ]]; then
    local pass note
    IFS=$'\t' read -r pass note <<<"${SEEN[$name]}"
    add "$name" "$pass" "$weight" "$note"
  else
    add "$name" 0 "$weight" "not emitted"
  fi
}

# Weights: happy-path small, hard checks (precedence/assoc/modulo/unary/
# errors) carry the bulk, perf high. Denominator is the SUM of all weights
# below plus the static checks - constant for every submission because every
# name is declared here unconditionally.
emit_check "imports" 6
emit_check "returns_float" 3

for n in hp_int hp_add hp_sub hp_mul hp_paren; do
  emit_check "$n" 2
done

for n in prec_add_mul prec_mul_add prec_mixed prec_div_add prec_chain prec_deep \
         assoc_sub assoc_div assoc_mix assoc_divmul; do
  emit_check "$n" 5
done

for n in mod_basic mod_prec mod_neg mod_float mod_chain; do
  emit_check "$n" 4
done

for n in un_lead un_add un_paren un_double un_after_op un_mul_neg un_prec; do
  emit_check "$n" 4
done

for n in flt_dec flt_lead flt_trail sci_e sci_neg sci_plus sci_expr truediv truediv_neg; do
  emit_check "$n" 3
done

for n in ws_none ws_pad ws_tabs nest_paren nest_deep; do
  emit_check "$n" 3
done

for n in err_empty err_ws_only err_unbal_open err_unbal_close err_unbal_nest \
         err_empty_paren err_empty_paren2 err_trail_op err_lead_op err_double_op \
         err_two_nums err_num_paren err_divzero err_modzero err_garbage_op err_letters; do
  emit_check "$n" 4
done

emit_check "valid_not_raise" 8

for n in perf_flat perf_mixed perf_nested; do
  emit_check "$n" 14
done

# --- emit final JSON (stdout) ; everything else above went to stderr ---
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
