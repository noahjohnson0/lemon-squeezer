import numpy as np
from scipy import stats

def linreg(x: list[float], y: list[float]) -> tuple[float, float, float]:
    """Ordinary least-squares linear regression. Returns (slope, intercept, r_squared)."""
    slope, intercept, r_value, p_value, std_err = stats.linregress(x, y)
    r_squared = r_value**2
    return slope, intercept, r_squared

def mean_ci95(data: list[float]) -> tuple[float, float, float]:
    """Returns (mean, ci_lower, ci_upper) — Student's t two-sided 95% CI for the mean.
    Use sample standard deviation (ddof=1). Raise ValueError if len(data) < 2."""
    n = len(data)
    if n < 2:
        raise ValueError("Data must contain at least two elements.")

    mean = np.mean(data)
    sem = stats.sem(data)

    # Calculate the t-value for a 95% confidence interval
    df = n - 1
    t_value = stats.t.ppf(0.975, df)

    ci_lower = mean - t_value * sem
    ci_upper = mean + t_value * sem

    return mean, ci_lower, ci_upper
