import numpy as np
from scipy.stats import t

def linreg(x: list[float], y: list[float]) -> tuple[float, float, float]:
    """Ordinary least-squares linear regression. Returns (slope, intercept, r_squared)."""
    if len(x) != len(y):
        raise ValueError("x and y must have the same length")
    n = len(x)
    x_mean = np.mean(x)
    y_mean = np.mean(y)
    numerator = np.sum((x - x_mean) * (y - y_mean))
    denominator = np.sum((x - x_mean) ** 2)
    slope = numerator / denominator
    intercept = y_mean - slope * x_mean
    r = numerator / np.sqrt(denominator * np.sum((y - y_mean) ** 2))
    r_squared = r ** 2
    return (slope, intercept, r_squared)

def mean_ci95(data: list[float]) -> tuple[float, float, float]:
    """Returns (mean, ci_lower, ci_upper) — Student's t two-sided 95% CI for the mean.
    Use sample standard deviation (ddof=1). Raise ValueError if len(data) < 2.
    You may use scipy.stats.t, OR a hardcoded t-table for df=1..30 plus normal approx beyond,
    OR compute the t-quantile yourself."""
    n = len(data)
    if n < 2:
        raise ValueError("Data must have at least 2 elements")
    mean = np.mean(data)
    std_dev = np.std(data, ddof=1)
    se = std_dev / np.sqrt(n)
    df = n - 1
    t_critical = t.ppf(0.975, df)
    ci_lower = mean - t_critical * se
    ci_upper = mean + t_critical * se
    return (mean, ci_lower, ci_upper)
