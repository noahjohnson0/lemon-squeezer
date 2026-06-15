#!/usr/bin/env bash
# Score a state-machine-engine workspace.
set -u
WS="${1:?workspace dir required}"
[[ -d "$WS" ]] || { echo "{\"error\":\"workspace not found\"}"; exit 1; }

declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  # sanitize note: drop backslashes, swap double-quotes for single
  note="${note//\\/}"
  note="${note//\"/\'}"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

E="$WS/engine.py"
O="$WS/order_workflow.py"
add "file:engine.py" "$([[ -f "$E" ]] && echo 1 || echo 0)" 3
add "file:order_workflow.py" "$([[ -f "$O" ]] && echo 1 || echo 0)" 3

if [[ -f "$E" && -f "$O" ]]; then
  python3 -m py_compile "$E" "$O" 2>/dev/null && add "compiles" 1 4 || add "compiles" 0 4

  RES=$(cd "$WS" && gtimeout 15 python3 - <<'PY' 2>&1
import sys

# Every check name this script is responsible for. Any not explicitly emitted
# below is reported as a failure in the final sweep -> constant denominator.
EXPECTED = [
    "builds", "initial_state", "history_seeded", "invalid_is_exc", "avail_cart",
    "cannot_ship_from_cart", "ship_from_cart_raises", "failed_fire_no_corrupt",
    "checkout", "guard_can_fire_amount", "pay_big_rejected",
    "pay_noamount_rejected", "pay_ok", "avail_paid", "ship_ok", "deliver_ok",
    "history_full", "audit_log", "refund_from_shipped", "cancel_from_pending",
    "independent_machines", "bad_initial_raises",
]
_seen = set()

def emit(name, ok, note=""):
    if name in _seen:
        return
    _seen.add(name)
    print("%s %d %s" % (name, 1 if ok else 0, note))

def check(name, fn):
    try:
        ok, note = fn()
        emit(name, ok, note)
    except Exception as e:
        emit(name, False, repr(e)[:70])

try:
    import engine
    from engine import StateMachine, Transition, InvalidTransition
    import order_workflow
    from order_workflow import build_order_machine, has_funds, get_audit_log
except Exception as e:
    print("IMPORT_ERR", repr(e)[:120])
    sys.exit(1)

# ---- generic engine basics ----
try:
    m = build_order_machine()
    emit("builds", True)
except Exception as e:
    emit("builds", False, repr(e)[:80])
    m = None

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

# Final sweep: anything not emitted (e.g. builds failed, exec stopped early)
# is a failure. Guarantees a constant denominator.
for name in EXPECTED:
    if name not in _seen:
        emit(name, False, "not reached")
PY
)
  echo "$RES" >&2
  if echo "$RES" | grep -q "^IMPORT_ERR"; then
    note=$(echo "$RES" | sed -n 's/^IMPORT_ERR //p' | head -1)
    for n in builds initial_state history_seeded invalid_is_exc avail_cart \
             cannot_ship_from_cart ship_from_cart_raises failed_fire_no_corrupt \
             checkout guard_can_fire_amount pay_big_rejected pay_noamount_rejected \
             pay_ok avail_paid ship_ok deliver_ok history_full audit_log \
             refund_from_shipped cancel_from_pending independent_machines \
             bad_initial_raises; do
      add "$n" 0 4 "import failed: $note"
    done
  else
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      name=$(echo "$line" | awk '{print $1}')
      pass=$(echo "$line" | awk '{print $2}')
      note=$(echo "$line" | cut -d' ' -f3-)
      [[ "$name" == "IMPORT_ERR" ]] && continue
      add "$name" "$pass" 4 "$note"
    done < <(echo "$RES")
  fi
else
  add "compiles" 0 4
  for n in builds initial_state history_seeded invalid_is_exc avail_cart \
           cannot_ship_from_cart ship_from_cart_raises failed_fire_no_corrupt \
           checkout guard_can_fire_amount pay_big_rejected pay_noamount_rejected \
           pay_ok avail_paid ship_ok deliver_ok history_full audit_log \
           refund_from_shipped cancel_from_pending independent_machines \
           bad_initial_raises; do
    add "$n" 0 4 "missing files"
  done
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
