import numpy as np
import scipy.stats as stats

def linreg(x: list[float], y: list[float]) -> tuple[float, float, float]:
    """Ordinary least-squares linear regression. Returns (slope, intercept, r_squared)."""
    x = np.array(x)
    y = np.array(y)
    if len(x) != len(y):
        raise ValueError("x and y must be of the same length")
    if len(x) < 2:
        raise ValueError("At least two data points required")
    if np.var(x) == 0:
        slope = 0.0
        intercept = np.mean(y)
        r_squared = 0.0
        return (slope, intercept, r_squared)
    slope = np.cov(x, y)[0, 1] / np.var(x)
    intercept = np.mean(y) - slope * np.mean(x)
    r_squared = np.corrcoef(x, y)[0, 1] ** 2
    return (slope, intercept, r_squared)

def mean_ci95(data: list[float]) -> tuple[float, float, float]:
    """Returns (mean, ci_lower, ci_upper) — Student's t two-sided 95% CI for the mean.
    Use sample standard deviation (ddof=1). Raise ValueError if len(data) < 2.
    You may use scipy.stats.t, OR a hardcoded t-table for df=1..30 plus normal approx beyond,
    OR compute the t-quantile yourself."""
    if len(data) < 2:
        raise ValueError("At least two data points required")
    n = len(data)
    mean = np.mean(data)
    std_dev = np.std(data, ddof=1)
    std_error = std_dev / np.sqrt(n)
    t_value = stats.t.ppf(1 - 0.05 / 2, df=n-1)
    margin_of_error = t_value * std_error
    ci_lower = mean - margin_of_error
    ci_upper = mean + margin_of_error
    return (mean, ci_lower, ci_upper)
