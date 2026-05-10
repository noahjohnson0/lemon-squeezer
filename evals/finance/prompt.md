Write `finance.py` exporting four functions for fixed-income / project finance arithmetic.

```python
def mortgage_payment(principal: float, annual_rate: float, years: int) -> float:
    """Fixed-rate, fully-amortizing monthly payment.
    annual_rate is decimal (0.06 == 6%). Returns the level monthly payment."""

def amortization_table(principal: float, annual_rate: float, years: int) -> list[dict]:
    """Return one dict per month with keys: month, payment, principal, interest, balance.
    Months numbered 1..N. Final balance must be exactly 0.0 (allow ±$0.01)."""

def npv(rate: float, cashflows: list[float]) -> float:
    """Net Present Value. cashflows[0] is at t=0 (typically negative); cashflows[i] at t=i.
    Discounted by (1+rate)^i."""

def irr(cashflows: list[float], guess: float = 0.1) -> float:
    """Internal Rate of Return — the rate r such that NPV(r, cashflows) == 0.
    Use Newton-Raphson or bisection. Must converge to within 1e-6 for typical inputs."""
```

Conventions:
- All amounts in same currency, in dollars (floats).
- Interest is simple monthly compounding (`monthly_rate = annual_rate / 12`).
- `mortgage_payment` formula: `P * r * (1+r)^n / ((1+r)^n - 1)` where `r = annual_rate/12`, `n = years*12`.
- `irr` should raise `ValueError` if it cannot converge.

Create only `finance.py`. Don't run it.
