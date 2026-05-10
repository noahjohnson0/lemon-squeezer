from typing import List, Tuple
import numpy as np
from scipy.stats import t

def linreg(x: List[float], y: List[float]) -> Tuple[float, float, float]:
    """Ordinary least-squares linear regression. Returns (slope, intercept, r_squared)."""
    x = np.array(x)
    y = np.array(y)
    
    slope, intercept, _, _, stderr = np.polyfit(x, y, 1, full=True)[0]
    residuals = y - (intercept + slope * x)
    ss_res = np.sum(residuals ** 2)
    ss_tot = np.sum((y - np.mean(y)) ** 2)
    
    r_squared = 1 - (ss_res / ss_tot) if ss_tot != 0 else float('nan')
    
    return slope, intercept, r_squared

def mean_ci95(data: List[float]) -> Tuple[float, float, float]:
    """Returns (mean, ci_lower, ci_upper) — Student's t two-sided 95% CI for the mean.
    Use sample standard deviation (ddof=1). Raise ValueError if len(data) < 2."""
    
    data = np.array(data)
    n = len(data)
    
    if n < 2:
        raise ValueError("Data must contain at least two elements.")
        
    mean = np.mean(data)
    std_err = np.std(data, ddof=1) / np.sqrt(n)
    t_value = t.ppf(0.975, df=n-1)

    ci_lower = mean - t_value * std_err
    ci_upper = mean + t_value * std_err
    
    return mean, ci_lower, ci_upper
