#!/usr/bin/env bash
# Score a repo-bugfix-ledger workspace.
set -u
WS="${1:?workspace dir required}"

declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  # sanitize note: strip backslashes, replace double-quotes with single
  note="${note//\\/}"
  note="${note//\"/\'}"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

PKG="$WS/ledger"
add "pkg:ledger" "$([[ -d "$PKG" ]] && echo 1 || echo 0)" 4

# All check names, in order, with weights (used for both pass and skip paths).
NAMES=(compiles asset_balance liability_sign balanced_post unbalanced_rejected unbalanced_no_mutation too_few_rejected transfer trial_balance_all books_balance net_worth top_n_count top_n_order top_more_than_exist)

# Single source of truth for weights -> constant denominator on every path.
weight_of() {
  case "$1" in
    compiles) echo 6;;
    asset_balance) echo 8;;
    liability_sign) echo 12;;
    balanced_post) echo 8;;
    unbalanced_rejected) echo 10;;
    unbalanced_no_mutation) echo 8;;
    too_few_rejected) echo 8;;
    transfer) echo 8;;
    trial_balance_all) echo 8;;
    books_balance) echo 8;;
    net_worth) echo 6;;
    top_n_count) echo 10;;
    top_n_order) echo 6;;
    top_more_than_exist) echo 4;;
    *) echo 5;;
  esac
}

if [[ -d "$PKG" ]]; then
  # compile all four modules
  if python3 -m py_compile "$PKG"/*.py 2>/dev/null; then add "compiles" 1 6; else add "compiles" 0 6; fi

  RES=$(cd "$WS" && gtimeout 15 python3 - <<'PY' 2>&1
import sys
def ok(b): return 1 if b else 0
try:
    from ledger import Ledger, Account, trial_balance, net_worth, top_accounts
except Exception as e:
    print("IMPORT_ERR", repr(e)); sys.exit(1)

# --- Account.balance sign ---
try:
    a = Account("cash", "asset")
    a.debit(100); a.credit(30)
    print("asset_balance", ok(abs(a.balance() - 70.0) < 1e-9), "got", a.balance())
except Exception as e:
    print("asset_balance", 0, "exc", type(e).__name__)

try:
    L = Account("loan", "liability"); L.credit(200); L.debit(50)
    E = Account("cap", "equity"); E.credit(80); E.debit(0)
    R = Account("rev", "revenue"); R.credit(120); R.debit(20)
    good = (abs(L.balance() - 150.0) < 1e-9 and E.balance() > 0 and abs(R.balance() - 100.0) < 1e-9)
    print("liability_sign", ok(good), "loan", L.balance(), "rev", R.balance())
except Exception as e:
    print("liability_sign", 0, "exc", type(e).__name__)

# --- balanced post applies ---
try:
    g = Ledger()
    g.open_account("cash", "asset")
    g.open_account("sales", "revenue")
    g.post([{"account": "cash", "side": "debit", "amount": 40},
            {"account": "sales", "side": "credit", "amount": 40}])
    good = abs(g.balance("cash") - 40.0) < 1e-9 and abs(g.balance("sales") - 40.0) < 1e-9
    print("balanced_post", ok(good), "cash", g.balance("cash"), "sales", g.balance("sales"))
except Exception as e:
    print("balanced_post", 0, "exc", type(e).__name__)

# --- unbalanced post rejected + no mutation ---
try:
    g = Ledger()
    g.open_account("cash", "asset")
    g.open_account("sales", "revenue")
    raised = False
    try:
        g.post([{"account": "cash", "side": "debit", "amount": 40},
                {"account": "sales", "side": "credit", "amount": 39}])
    except ValueError:
        raised = True
    except Exception:
        raised = False
    print("unbalanced_rejected", ok(raised))
    # accounts must be untouched (all-or-nothing)
    clean = abs(g.balance("cash") - 0.0) < 1e-9 and abs(g.balance("sales") - 0.0) < 1e-9
    print("unbalanced_no_mutation", ok(clean), "cash", g.balance("cash"), "sales", g.balance("sales"))
except Exception as e:
    print("unbalanced_rejected", 0, "exc", type(e).__name__)
    print("unbalanced_no_mutation", 0, "exc", type(e).__name__)

# --- too few entries rejected ---
try:
    g = Ledger(); g.open_account("cash", "asset")
    raised = False
    try:
        g.post([{"account": "cash", "side": "debit", "amount": 10}])
    except ValueError:
        raised = True
    except Exception:
        raised = False
    print("too_few_rejected", ok(raised))
except Exception as e:
    print("too_few_rejected", 0, "exc", type(e).__name__)

# --- transfer ---
try:
    g = Ledger()
    g.open_account("a", "asset"); g.open_account("b", "asset")
    g.open_account("eq", "equity")
    # seed a with 100 via a balanced opening entry
    g.post([{"account": "a", "side": "debit", "amount": 100},
            {"account": "eq", "side": "credit", "amount": 100}])
    g.transfer("a", "b", 25)
    good = abs(g.balance("a") - 75.0) < 1e-9 and abs(g.balance("b") - 25.0) < 1e-9
    print("transfer", ok(good), "a", g.balance("a"), "b", g.balance("b"))
except Exception as e:
    print("transfer", 0, "exc", type(e).__name__)

# --- trial_balance returns every account + books balance + net_worth ---
try:
    g = Ledger()
    g.open_account("cash", "asset")
    g.open_account("equip", "asset")
    g.open_account("loan", "liability")
    g.open_account("equity", "equity")
    # cash 100 (debit), equity 100 (credit)
    g.post([{"account": "cash", "side": "debit", "amount": 100},
            {"account": "equity", "side": "credit", "amount": 100}])
    # buy equipment 75 with a loan: equip debit 75, loan credit 75
    g.post([{"account": "equip", "side": "debit", "amount": 75},
            {"account": "loan", "side": "credit", "amount": 75}])
    # pay down 25 of loan from cash: loan debit 25, cash credit 25
    g.post([{"account": "loan", "side": "debit", "amount": 25},
            {"account": "cash", "side": "credit", "amount": 25}])

    tb = trial_balance(g)
    print("trial_balance_all", ok(isinstance(tb, dict) and len(tb) == 4), "n", (len(tb) if isinstance(tb, dict) else -1))

    # debit-normal total == credit-normal total
    dn = g.balance("cash") + g.balance("equip")
    cn = g.balance("loan") + g.balance("equity")
    print("books_balance", ok(abs(dn - cn) < 1e-9), "dn", dn, "cn", cn)

    # assets: cash 75 + equip 75 = 150; liabilities: loan 50 -> net 100
    nw = net_worth(g)
    print("net_worth", ok(abs(nw - 100.0) < 1e-9), "got", nw)
except Exception as e:
    print("trial_balance_all", 0, "exc", type(e).__name__)
    print("books_balance", 0, "exc", type(e).__name__)
    print("net_worth", 0, "exc", type(e).__name__)

# --- top_accounts count / order / over-ask ---
try:
    g = Ledger()
    g.open_account("big", "asset")
    g.open_account("mid", "asset")
    g.open_account("small", "asset")
    g.open_account("eq", "equity")
    g.post([{"account": "big", "side": "debit", "amount": 300},
            {"account": "eq", "side": "credit", "amount": 300}])
    g.post([{"account": "mid", "side": "debit", "amount": 200},
            {"account": "eq", "side": "credit", "amount": 200}])
    g.post([{"account": "small", "side": "debit", "amount": 100},
            {"account": "eq", "side": "credit", "amount": 100}])
    t3 = top_accounts(g, 3)
    print("top_n_count", ok(isinstance(t3, list) and len(t3) == 3), "n", (len(t3) if isinstance(t3, list) else -1))
    names = [x[0] for x in t3] if isinstance(t3, list) else []
    # eq has balance 600 (abs largest), then big 300, mid 200
    print("top_n_order", ok(names == ["eq", "big", "mid"]), "order", ",".join(names))
    t99 = top_accounts(g, 99)
    print("top_more_than_exist", ok(isinstance(t99, list) and len(t99) == 4), "n", (len(t99) if isinstance(t99, list) else -1))
except Exception as e:
    print("top_n_count", 0, "exc", type(e).__name__)
    print("top_n_order", 0, "exc", type(e).__name__)
    print("top_more_than_exist", 0, "exc", type(e).__name__)
PY
)
  echo "$RES" >&2

  if echo "$RES" | grep -q "IMPORT_ERR"; then
    note=$(echo "$RES" | sed -n 's/^IMPORT_ERR //p' | head -1)
    for nm in "${NAMES[@]}"; do
      [[ "$nm" == "compiles" ]] && continue
      add "$nm" 0 "$(weight_of "$nm")" "import failed: $note"
    done
  else
    for nm in "${NAMES[@]}"; do
      [[ "$nm" == "compiles" ]] && continue
      line=$(echo "$RES" | awk -v k="$nm" '$1==k {print; exit}')
      if [[ -z "$line" ]]; then
        add "$nm" 0 "$(weight_of "$nm")" "no result line"
      else
        pass=$(echo "$line" | awk '{print $2}')
        note=$(echo "$line" | cut -d' ' -f3-)
        add "$nm" "$pass" "$(weight_of "$nm")" "$note"
      fi
    done
  fi
else
  # package missing: add every check at its weight, all failing
  for nm in "${NAMES[@]}"; do
    add "$nm" 0 "$(weight_of "$nm")"
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
