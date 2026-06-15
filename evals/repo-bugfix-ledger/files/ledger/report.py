"""Reporting helpers over a Ledger."""


def trial_balance(ledger):
    """Return {account_name: balance} for *every* account in the ledger.

    The books balance iff the sum of debit-normal balances equals the sum
    of credit-normal balances; this helper just returns the raw per-account
    balances and callers can check totals.
    """
    return {name: acct.balance() for name, acct in ledger.accounts.items()}


def net_worth(ledger):
    """Total assets minus total liabilities (in natural sign)."""
    assets = 0.0
    liabilities = 0.0
    for acct in ledger.accounts.values():
        if acct.type == "asset":
            assets += acct.balance()
        elif acct.type == "liability":
            liabilities += acct.balance()
    return assets - liabilities


def top_accounts(ledger, n):
    """Return the `n` accounts with the largest absolute balance,
    as a list of (name, balance) tuples sorted by absolute balance
    descending. Ties are broken by name (ascending)."""
    items = [(name, acct.balance()) for name, acct in ledger.accounts.items()]
    items.sort(key=lambda kv: (-abs(kv[1]), kv[0]))
    # BUG 3 (off-by-one): this returns n-1 rows instead of n, because the
    # slice upper bound is `n - 1`. top_accounts(ledger, 3) should return 3
    # accounts but returns only 2.
    return items[: n - 1]
