Write `stats.py` exporting:

```python
def linreg(x: list[float], y: list[float]) -> tuple[float, float, float]:
    """Ordinary least-squares linear regression. Returns (slope, intercept, r_squared)."""

def mean_ci95(data: list[float]) -> tuple[float, float, float]:
    """Returns (mean, ci_lower, ci_upper) — Student's t two-sided 95% CI for the mean.
    Use sample standard deviation (ddof=1). Raise ValueError if len(data) < 2.
    You may use scipy.stats.t, OR a hardcoded t-table for df=1..30 plus normal approx beyond,
    OR compute the t-quantile yourself."""
```

Pure stdlib + numpy/scipy if needed (no plotting libs). No raw R reimplementations.

Create only `stats.py`. Don't run it.
