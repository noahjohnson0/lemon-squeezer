"""Posting transactions into the ledger.

A transaction is a list of *entries*. Each entry is a dict:

    {"account": <name>, "side": "debit"|"credit", "amount": <number>}

A transaction is only valid if total debits == total credits (the
fundamental rule of double-entry book-keeping) and it has at least
two entries. Posting an invalid transaction must raise ValueError and
must NOT mutate any account (all-or-nothing).
"""

from .account import Account


class Ledger:
    def __init__(self):
        self.accounts = {}

    def open_account(self, name, type):
        if name in self.accounts:
            raise ValueError("account already exists: %r" % (name,))
        acct = Account(name, type)
        self.accounts[name] = acct
        return acct

    def get(self, name):
        return self.accounts[name]

    def balance(self, name):
        return self.accounts[name].balance()

    def post(self, entries):
        """Validate and apply a balanced transaction atomically."""
        if len(entries) < 2:
            raise ValueError("a transaction needs at least two entries")

        total_debit = 0.0
        total_credit = 0.0
        for e in entries:
            if e["account"] not in self.accounts:
                raise ValueError("no such account: %r" % (e["account"],))
            if e["amount"] < 0:
                raise ValueError("amount must be non-negative")
            if e["side"] == "debit":
                total_debit += e["amount"]
            elif e["side"] == "credit":
                total_credit += e["amount"]
            else:
                raise ValueError("side must be 'debit' or 'credit'")

        # BUG 2 (missing edge case / wrong validation): a transaction is only
        # valid when debits == credits. This check is missing entirely, so an
        # unbalanced transaction is happily applied, silently corrupting the
        # books. (The correct code must reject total_debit != total_credit
        # BEFORE mutating any account.)

        for e in entries:
            acct = self.accounts[e["account"]]
            if e["side"] == "debit":
                acct.debit(e["amount"])
            else:
                acct.credit(e["amount"])

    def transfer(self, src, dst, amount):
        """Move `amount` from `src` account to `dst` account.

        Convenience wrapper that posts a balanced two-entry transaction:
        debit dst, credit src.
        """
        self.post([
            {"account": dst, "side": "debit", "amount": amount},
            {"account": src, "side": "credit", "amount": amount},
        ])
