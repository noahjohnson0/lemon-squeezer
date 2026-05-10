"""
Utility statistical functions.

Provides:
- linreg: Ordinary least-squares linear regression.
- mean_ci95: 95 % confidence interval for the mean using Student's t distribution.
"""

from __future__ import annotations

from typing import List, Tuple

import numpy as np

try:
    # scipy is optional; if available we use it for the t‑quantile.
    from scipy.stats import t as _scipy_t
except Exception:  # pragma: no cover
    _scipy_t = None


def linreg(x: List[float], y: List[float]) -> Tuple[float, float, float]:
    """
    Ordinary least-squares linear regression.

    Parameters
    ----------
    x : list[float]
        Independent variable values.
    y : list[float]
        Dependent variable values.

    Returns
    -------
    slope : float
        Estimated slope of the regression line.
    intercept : float
        Estimated intercept of the regression line.
    r_squared : float
        Coefficient of determination (R²) of the fit.

    Raises
    ------
    ValueError
        If the input lists are of different lengths or contain fewer than two points.
    """
    if len(x) != len(y):
        raise ValueError("x and y must have the same length")
    if len(x) < 2:
        raise ValueError("At least two data points are required for linear regression")

    x_arr = np.asarray(x, dtype=float)
    y_arr = np.asarray(y, dtype=float)

    # Compute means
    x_mean = np.mean(x_arr)
    y_mean = np.mean(y_arr)

    # Compute slope (beta1) and intercept (beta0)
    numerator = np.sum((x_arr - x_mean) * (y_arr - y_mean))
    denominator = np.sum((x_arr - x_mean) ** 2)
    slope = numerator / denominator
    intercept = y_mean - slope * x_mean

    # Compute R²
    y_pred = slope * x_arr + intercept
    ss_res = np.sum((y_arr - y_pred) ** 2)
    ss_tot = np.sum((y_arr - y_mean) ** 2)
    r_squared = 1 - ss_res / ss_tot if ss_tot != 0 else 0.0

    return slope, intercept, r_squared


def mean_ci95(data: List[float]) -> Tuple[float, float, float]:
    """
    Returns the sample mean and a two‑sided 95 % confidence interval for the mean
    using Student's t distribution.

    Parameters
    ----------
    data : list[float]
        Sample data.

    Returns
    -------
    mean : float
        Sample mean.
    ci_lower : float
        Lower bound of the 95 % confidence interval.
    ci_upper : float
        Upper bound of the 95 % confidence interval.

    Raises
    ------
    ValueError
        If the sample contains fewer than two observations.
    """
    n = len(data)
    if n < 2:
        raise ValueError("At least two data points are required to compute a confidence interval")

    arr = np.asarray(data, dtype=float)
    mean = np.mean(arr)
    # Sample standard deviation with Bessel's correction (ddof=1)
    std_dev = np.std(arr, ddof=1)
    se = std_dev / np.sqrt(n)  # Standard error of the mean

    df = n - 1  # degrees of freedom

    # Determine the t critical value
    if _scipy_t is not None:
        t_crit = _scipy_t.ppf(0.975, df)
    else:
        # Fallback: use a hard‑coded t‑table for df up to 30, normal approximation beyond
        _t_table = {
            1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571,
            6: 2.447, 7: 2.365, 8: 2.306, 9: 2.262, 10: 2.228,
            11: 2.201, 12: 2.179, 13: 2.160, 14: 2.145, 15: 2.131,
            16: 2.120, 17: 2.110, 18: 2.101, 19: 2.093, 20: 2.086,
            21: 2.080, 22: 2.074, 23: 2.069, 24: 2.064, 25: 2.060,
            26: 2.056, 27: 2.052, 28: 2.048, 29: 2.045, 30: 2.042,
        }
        if df <= 30:
            t_crit = _t_table[df]
        else:
            # Normal approximation for large df
            t_crit = 1.96

    ci_lower = mean - t_crit * se
    ci_upper = mean + t_crit * se

    return mean, ci_lower, ci_upper
