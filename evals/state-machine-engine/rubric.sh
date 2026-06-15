#!/usr/bin/env bash
# Score a state-machine-engine workspace.
#
# HARDENING NOTES (why this looks the way it does):
#  * CONSTANT DENOMINATOR. Every declared check is ALWAYS emitted exactly once,
#    pass=1 or pass=0, regardless of how broken the submission is. The python
#    block never sys.exit()s; an import failure just flips a flag and every
#    behavioral check reports 0. A final bash sweep adds any check the python
#    block somehow failed to print (e.g. a hard crash/timeout mid-run) as 0.
#  * NO STDOUT POISONING. Protocol lines from the python block are prefixed with
#    a unique sentinel (@@CHK@@). The bash parser accepts ONLY sentinel lines
#    whose check name is on a fixed whitelist, and dedups them (first wins).
#    A submission that print()s "audit_log 1" on import cannot inflate the
#    denominator or fake a pass: no sentinel, not whitelisted, and deduped.
#  * STDOUT vs STDERR. The python block prints diagnostics to stderr; only
#    sentinel protocol lines go to stdout. The rubric's own final JSON is the
#    only thing this script writes to stdout.
set -u
WS="${1:?workspace dir required}"
[[ -d "$WS" ]] || { echo "{\"error\":\"workspace not found\"}"; exit 1; }

# Fixed whitelist of behavioral check names + the explicit imports check.
# This list is the single source of truth for the behavioral denominator.
BEHAV=(imports builds initial_state history_seeded invalid_is_exc avail_cart \
       cannot_ship_from_cart ship_from_cart_raises failed_fire_no_corrupt \
       checkout guard_can_fire_amount pay_big_rejected pay_noamount_rejected \
       pay_ok avail_paid ship_ok deliver_ok history_full audit_log \
       refund_from_shipped cancel_from_pending independent_machines \
       bad_initial_raises)
BEHAV_WEIGHT=4

declare -a checks
declare -A seen=()
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ -n "${seen[$n]:-}" ]] && return   # first occurrence of a name wins
  seen[$n]=1
  [[ "$p" != "1" ]] && p=0
  # sanitize note: drop backslashes, swap double-quotes for single, kill tabs/newlines
  note="${note//\\/}"
  note="${note//\"/\'}"
  note="${note//$'\t'/ }"
  note="${note//$'\n'/ }"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

# Add every behavioral check at its weight, defaulting to 0 with the given note.
# Used as the final sweep so the denominator is constant no matter what.
sweep_behav() {
  local note="${1:-not reached}" n
  for n in "${BEHAV[@]}"; do
    add "$n" 0 "$BEHAV_WEIGHT" "$note"
  done
}

E="$WS/engine.py"
O="$WS/order_workflow.py"
add "file:engine.py" "$([[ -f "$E" ]] && echo 1 || echo 0)" 3
add "file:order_workflow.py" "$([[ -f "$O" ]] && echo 1 || echo 0)" 3

if [[ -f "$E" && -f "$O" ]]; then
  if python3 -m py_compile "$E" "$O" 2>/dev/null; then
    add "compiles" 1 4
  else
    add "compiles" 0 4
  fi

  # The python block emits protocol lines as: <SENT> <name> <0|1> [note...]
  # where <SENT> is a per-run RANDOM nonce the submission cannot predict.
  # Defense in depth: at the OS fd level we point the submission's stdout (fd 1)
  # at stderr, so ANY print() the submission does -- on import, in fire(), in a
  # hook -- lands on stderr and can NEVER reach the protocol stream. Protocol
  # lines are written to a saved dup of the original stdout. So neither
  # forged sentinel lines nor noisy prints can fake a pass or alter the count.
  SENT="@@CHK_$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')@@"
  RES=$( cd "$WS" && LEMON_SENT="$SENT" gtimeout 15 python3 - <<'PY' 2>>/dev/null
import sys, os

SENT = os.environ.get("LEMON_SENT", "@@CHK@@")
_seen = set()

# Reserve the REAL stdout for the protocol, then redirect fd 1 -> fd 2 so the
# submission's prints cannot pollute the protocol stream.
_proto_fd = os.dup(1)
try:
    os.dup2(2, 1)            # anything written to fd 1 now goes to stderr
    sys.stdout = os.fdopen(2, "w", closefd=False)
except Exception:
    _proto_fd = 1            # fallback: best-effort, still nonce-protected

def _proto_write(s):
    try:
        os.write(_proto_fd, s.encode("utf-8", "replace"))
    except Exception:
        pass

def emit(name, ok, note=""):
    if name in _seen:
        return
    _seen.add(name)
    note = str(note).replace("\n", " ").replace("\t", " ")
    _proto_write("%s %s %d %s\n" % (SENT, name, 1 if ok else 0, note))

def check(name, fn):
    try:
        ok, note = fn()
        emit(name, ok, note)
    except Exception as e:
        emit(name, False, repr(e)[:70])

# ---- import (never sys.exit; failure -> flag, every check still emitted) ----
imports_ok = True
StateMachine = Transition = InvalidTransition = None
build_order_machine = has_funds = get_audit_log = None
try:
    import engine
    from engine import StateMachine, Transition, InvalidTransition
    import order_workflow
    from order_workflow import build_order_machine, has_funds, get_audit_log
except Exception as e:
    imports_ok = False
    sys.stderr.write("IMPORT_ERR %s\n" % (repr(e)[:120],))

emit("imports", imports_ok, "" if imports_ok else "import failed")

# ---- build the machine (only if imports worked) ----
m = None
if imports_ok:
    try:
        m = build_order_machine()
        emit("builds", True)
    except Exception as e:
        emit("builds", False, repr(e)[:80])
        m = None
else:
    emit("builds", False, "no import")

if m is not None:
    check("initial_state", lambda: (m.state == "cart", "got=%r" % (m.state,)))
    check("history_seeded", lambda: (list(m.history) == ["cart"], "got=%r" % (list(m.history),)))
    check("invalid_is_exc", lambda: (isinstance(InvalidTransition(), Exception), ""))
    check("avail_cart", lambda: (list(m.available_events()) == ["cancel", "checkout"], "got=%r" % (list(m.available_events()),)))
    check("cannot_ship_from_cart", lambda: (m.can_fire("ship") is False, ""))

    def _ship_from_cart():
        try:
            m.fire("ship")
            return False, "no raise"
        except InvalidTransition as e:
            msg = str(e)
            return (("ship" in msg) and ("cart" in msg)), "msg=%r" % (msg[:60],)
        except Exception as e:
            return False, "wrong exc %s" % type(e).__name__
    check("ship_from_cart_raises", _ship_from_cart)
    check("failed_fire_no_corrupt", lambda: (m.state == "cart" and list(m.history) == ["cart"], ""))

    # ---- checkout ----
    def _checkout():
        r = m.fire("checkout")
        return (m.state == "pending" and r == "pending"), "got=%r" % (m.state,)
    check("checkout", _checkout)

    # ---- guard: pay rejected when amount too big / missing ----
    check("guard_can_fire_amount", lambda: (m.can_fire("pay", amount=50) is True and m.can_fire("pay", amount=200) is False, ""))

    def _pay_big():
        try:
            m.fire("pay", amount=200)
            return False, "no raise; state=%r" % (m.state,)
        except InvalidTransition:
            return (m.state == "pending"), "state=%r" % (m.state,)
        except Exception as e:
            return False, "wrong exc %s" % type(e).__name__
    check("pay_big_rejected", _pay_big)

    def _pay_noamt():
        try:
            m.fire("pay")
            return False, "no raise"
        except InvalidTransition:
            return True, ""
        except Exception as e:
            return False, "wrong exc %s" % type(e).__name__
    check("pay_noamount_rejected", _pay_noamt)

    # ---- guard accepts, walk happy path ----
    def _pay_ok():
        m.fire("pay", amount=50)
        return (m.state == "paid"), "got=%r" % (m.state,)
    check("pay_ok", _pay_ok)

    check("avail_paid", lambda: (list(m.available_events()) == ["cancel", "refund", "ship"], "got=%r" % (list(m.available_events()),)))

    def _ship_ok():
        m.fire("ship")
        return (m.state == "shipped"), "got=%r" % (m.state,)
    check("ship_ok", _ship_ok)

    def _deliver_ok():
        m.fire("deliver")
        return (m.state == "delivered"), "got=%r" % (m.state,)
    check("deliver_ok", _deliver_ok)

    check("history_full", lambda: (list(m.history) == ["cart", "pending", "paid", "shipped", "delivered"], "got=%r" % (list(m.history),)))
    check("audit_log", lambda: (list(get_audit_log(m)) == ["shipped", "delivered"], "got=%r" % (list(get_audit_log(m)),)))

    # ---- multi-edge selection by state: refund from shipped ----
    def _refund_shipped():
        m2 = build_order_machine()
        m2.fire("checkout"); m2.fire("pay", amount=10); m2.fire("ship")
        m2.fire("refund")  # refund:shipped->refunded
        return (m2.state == "refunded"), "got=%r" % (m2.state,)
    check("refund_from_shipped", _refund_shipped)

    # cancel from pending (different edge, same event)
    def _cancel_pending():
        m3 = build_order_machine()
        m3.fire("checkout")
        m3.fire("cancel")  # cancel:pending->cancelled
        return (m3.state == "cancelled"), "got=%r" % (m3.state,)
    check("cancel_from_pending", _cancel_pending)

    # ---- independence: separate machines don't share state/history/audit ----
    def _independent():
        a = build_order_machine(); b = build_order_machine()
        a.fire("checkout"); a.fire("pay", amount=5); a.fire("ship")
        ok = (b.state == "cart" and list(b.history) == ["cart"] and list(get_audit_log(b)) == [])
        return ok, "b.state=%r b.audit=%r" % (b.state, list(get_audit_log(b)))
    check("independent_machines", _independent)

    # ---- constructor validation ----
    def _bad_initial():
        try:
            StateMachine(["a", "b"], "z", [])
            return False, "no raise"
        except ValueError:
            return True, ""
        except Exception as e:
            return False, "wrong exc %s" % type(e).__name__
    check("bad_initial_raises", _bad_initial)

# Final python-side sweep: every EXPECTED behavioral check that didn't get
# emitted (build failed, or import failed, or some path skipped it) is a 0.
EXPECTED = [
    "imports", "builds", "initial_state", "history_seeded", "invalid_is_exc",
    "avail_cart", "cannot_ship_from_cart", "ship_from_cart_raises",
    "failed_fire_no_corrupt", "checkout", "guard_can_fire_amount",
    "pay_big_rejected", "pay_noamount_rejected", "pay_ok", "avail_paid",
    "ship_ok", "deliver_ok", "history_full", "audit_log",
    "refund_from_shipped", "cancel_from_pending", "independent_machines",
    "bad_initial_raises",
]
for name in EXPECTED:
    if name not in _seen:
        emit(name, False, "not reached")
PY
)
  # Dump raw protocol output to stderr for debugging (never to stdout).
  printf '%s\n' "$RES" >&2

  # Parse ONLY protocol lines carrying the per-run nonce AND a whitelisted name.
  # The nonce ($SENT) is unpredictable, so a submission cannot forge a line.
  declare -A is_behav=()
  for n in "${BEHAV[@]}"; do is_behav[$n]=1; done
  while IFS= read -r line; do
    [[ "$line" == "$SENT "* ]] || continue         # must carry the run nonce
    rest="${line#"$SENT" }"
    name=$(printf '%s' "$rest" | awk '{print $1}')
    pass=$(printf '%s' "$rest" | awk '{print $2}')
    note=$(printf '%s' "$rest" | cut -d' ' -f3-)
    [[ -n "${is_behav[$name]:-}" ]] || continue    # ignore non-whitelisted names
    add "$name" "$pass" "$BEHAV_WEIGHT" "$note"
  done < <(printf '%s\n' "$RES")

  # Sweep: any whitelisted behavioral check not emitted by python (crash,
  # timeout, truncated stdout) is added as 0. Guarantees constant denominator.
  sweep_behav "not emitted"
else
  add "compiles" 0 4
  sweep_behav "missing files"
fi

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
