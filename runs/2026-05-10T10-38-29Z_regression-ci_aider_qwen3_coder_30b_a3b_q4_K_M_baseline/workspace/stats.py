import numpy as np
from scipy import stats
from typing import tuple

def linreg(x: list[float], y: list[float]) -> tuple[float, float, float]:
    """Ordinary least-squares linear regression. Returns (slope, intercept, r_squared)."""
    if len(x) != len(y):
        raise ValueError("x and y must have the same length")
    
    # Convert to numpy arrays
    x = np.array(x)
    y = np.array(y)
    
    # Calculate means
    x_mean = np.mean(x)
    y_mean = np.mean(y)
    
    # Calculate slope (beta1)
    numerator = np.sum((x - x_mean) * (y - y_mean))
    denominator = np.sum((x - x_mean) ** 2)
    slope = numerator / denominator
    
    # Calculate intercept (beta0)
    intercept = y_mean - slope * x_mean
    
    # Calculate R-squared
    y_pred = slope * x + intercept
    ss_res = np.sum((y - y_pred) ** 2)
    ss_tot = np.sum((y - y_mean) ** 2)
    r_squared = 1 - (ss_res / ss_tot)
    
    return (slope, intercept, r_squared)

def mean_ci95(data: list[float]) -> tuple[float, float, float]:
    """Returns (mean, ci_lower, ci_upper) — Student's t two-sided 95% CI for the mean.
    Use sample standard deviation (ddof=1). Raise ValueError if len(data) < 2.
    You may use scipy.stats.t, OR a hardcoded t-table for df=1..30 plus normal approx beyond,
    OR compute the t-quantile yourself."""
    if len(data) < 2:
        raise ValueError("Data must contain at least 2 elements")
    
    # Convert to numpy array
    data = np.array(data)
    
    # Calculate mean
    mean = np.mean(data)
    
    # Calculate sample standard deviation (ddof=1)
    std_dev = np.std(data, ddof=1)
    
    # Calculate standard error
    n = len(data)
    std_error = std_dev / np.sqrt(n)
    
    # Calculate degrees of freedom
    df = n - 1
    
    # Get t-value for 95% confidence interval (two-tailed)
    # Using scipy.stats.t.ppf for the critical value
    t_critical = stats.t.ppf(0.975, df)  # 0.975 because it's two-tailed
    
    # Calculate margin of error
    margin_error = t_critical * std_error
    
    # Calculate confidence interval
    ci_lower = mean - margin_error
    ci_upper = mean + margin_error
    
    return (mean, ci_lower, ci_upper)
