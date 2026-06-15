# Fix the double-entry ledger library

The `ledger/` package in this directory is a small double-entry book-keeping
library. It has bugs that produce **wrong balances and wrong reports**. Fix the
implementation (edit the files under `ledger/`) so that **all** of the behaviors
below hold. Do not change the public API or the function/method names - only fix
the logic. Do not add new dependencies (standard library only).

## The package

```
ledger/__init__.py   # exports the public API (do not rename anything)
ledger/account.py    # Account class: tracks debits/credits, computes balance()
ledger/posting.py    # Ledger class: open_account, post, transfer, balance
ledger/report.py     # trial_balance, net_worth, top_accounts
```

## Accounting model (this part is correct - match it)

Every account has a *type* that fixes its **normal balance**:

- `asset`, `expense` are **debit-normal**: debits increase the balance, credits decrease it.
- `liability`, `equity`, `revenue` are **credit-normal**: credits increase the balance, debits decrease it.

`Account.balance()` must return the balance in the account's **natural sign** -
a positive number means "more of what this account normally holds".

## Required behaviors

Use these exactly; they are the acceptance criteria.

1. **Asset balance.** An `asset` account with 100 of debits and 30 of credits has
   `balance() == 70`.

2. **Liability balance (sign).** A `liability` account with 200 of credits and 50
   of debits has `balance() == 150` (NOT `-150`). Likewise an `equity` or
   `revenue` account with more credits than debits has a **positive** balance.

3. **Balanced post applies.** `Ledger.post(entries)` applies a transaction whose
   total debits equal total credits. After opening `cash` (asset) and `sales`
   (revenue) and posting a debit of 40 to `cash` and a credit of 40 to `sales`,
   `balance("cash") == 40` and `balance("sales") == 40`.

4. **Unbalanced post is rejected.** `post(entries)` must raise `ValueError` when
   total debits != total credits, and must **not** mutate any account (all or
   nothing). After a rejected post, every account balance is unchanged.

5. **Too-few-entries rejected.** `post(entries)` with fewer than two entries
   raises `ValueError`.

6. **Transfer.** `Ledger.transfer(src, dst, amount)` moves `amount` from `src` to
   `dst` by posting a balanced two-entry transaction (debit `dst`, credit `src`).
   Transferring 25 between two `asset` accounts `a` (starting balance 100) and
   `b` (starting balance 0) leaves `balance("a") == 75` and `balance("b") == 25`.

7. **trial_balance returns every account.** `trial_balance(ledger)` returns a
   dict mapping **every** account name to its `balance()`. For a ledger with 4
   accounts the dict has 4 entries.

8. **Books balance.** For a correctly-posted ledger, the sum of the balances of
   all debit-normal accounts equals the sum of the balances of all credit-normal
   accounts.

9. **net_worth.** `net_worth(ledger)` returns total asset balances minus total
   liability balances (each in natural sign). With assets summing to 175 and
   liabilities summing to 50, `net_worth == 125`.

10. **top_accounts returns n rows.** `top_accounts(ledger, n)` returns the `n`
    accounts with the largest **absolute** balance as a list of
    `(name, balance)` tuples, sorted by absolute balance descending (ties broken
    by name ascending). `top_accounts(ledger, 3)` on a ledger with at least 3
    accounts returns exactly **3** tuples; asking for more accounts than exist
    returns them all.

Fix the files in place. Don't worry about running anything - just make the
behaviors above true.
