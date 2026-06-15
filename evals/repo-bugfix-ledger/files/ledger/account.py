"""Account model for the double-entry ledger.

Every account has a *type* which determines its **normal balance**:

    asset, expense      -> normal balance is DEBIT  (debits increase, credits decrease)
    liability, equity, revenue -> normal balance is CREDIT (credits increase, debits decrease)

`balance()` always returns the balance in the account's *natural* sign:
a positive number means "more of what this account normally holds".
So an asset with 100 of debits and 30 of credits has balance 70.
A revenue account with 200 of credits and 50 of debits has balance 150.
"""

DEBIT_NORMAL = ("asset", "expense")
CREDIT_NORMAL = ("liability", "equity", "revenue")
VALID_TYPES = DEBIT_NORMAL + CREDIT_NORMAL


class Account:
    def __init__(self, name, type):
        if type not in VALID_TYPES:
            raise ValueError("unknown account type: %r" % (type,))
        self.name = name
        self.type = type
        self._debits = 0.0
        self._credits = 0.0

    def debit(self, amount):
        if amount < 0:
            raise ValueError("amount must be non-negative")
        self._debits += amount

    def credit(self, amount):
        if amount < 0:
            raise ValueError("amount must be non-negative")
        self._credits += amount

    @property
    def total_debits(self):
        return self._debits

    @property
    def total_credits(self):
        return self._credits

    def balance(self):
        """Balance in the account's natural (normal-balance) sign."""
        return self._debits - self._credits

    def __repr__(self):
        return "Account(%r, %r, balance=%s)" % (self.name, self.type, self.balance())
