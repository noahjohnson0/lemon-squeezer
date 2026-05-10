"""Utility statistics functions.

This module provides two public functions:

* ``linreg``  – Ordinary least squares linear regression.
* ``mean_ci95`` – 95 % Student's *t* confidence interval for the mean.

Both functions use only NumPy and optionally SciPy (for ``stats.t``).  If
SciPy is not available the ``mean_ci95`` fallback uses an approximation of
the *t* quantile through a hard‑coded t–table for df ≤ 30 combined with
the normal approximation for larger samples.

The functions are minimal and aimed at educational use rather than
performance – ``linreg`` uses a plain implementation that is sufficiently
accurate for small data sets.
"""

from __future__ import annotations

from typing import Sequence, Tuple

import numpy as np

# Try to import scipy.stats.t; if unavailable, use a lightweight
# approximation.
try:
    from scipy.stats import t as _scipy_t  # type: ignore
except Exception:  # pragma: no cover – SciPy optional
    _scipy_t = None

# A minimal *t* table for df = 1 … 30.  Values are two‑sided 95 % critical
# values (i.e. the 97.5th percentile).
_T_TABLE_95 = {
    1: 12.706,
    2: 4.303,
    3: 3.182,
    4: 2.776,
    5: 2.571,
    6: 2.447,
    7: 2.365,
    8: 2.306,
    9: 2.262,
    10: 2.228,
    11: 2.201,
    12: 2.179,
    13: 2.160,
    14: 2.145,
    15: 2.131,
    16: 2.12,
    17: 2.110,
    18: 2.101,
    19: 2.093,
    20: 2.086,
    21: 2.080,
    22: 2.074,
    23: 2.069,
    24: 2.064,
    25: 2.060,
    26: 2.056,
    27: 2.052,
    28: 2.048,
    29: 2.045,
    30: 2.042,
}


def linreg(x: Sequence[float], y: Sequence[float]) -> Tuple[float, float, float]:
    """Ordinary least‑squares linear regression.

    Parameters
    ----------
    x:
        Independent variable observations.
    y:
        Dependent variable observations.

    Returns
    -------
    slope,
        Estimated slope ``(y = slope * x + intercept)``.
    intercept,
        Estimated intercept.
    r_squared,
        Coefficient of determination :math:`R^2`.

    Notes
    -----
    Compute means and covariance and perform the standard OLS computation.
    """
    if len(x) != len(y):
        raise ValueError("Sequences x and y must have the same length.")
    if not x:
        raise ValueError("Sequences x and y must not be empty.")

    xb = np.asarray(x, dtype=float)
    yb = np.asarray(y, dtype=float)
    mean_x = xb.mean()
    mean_y = yb.mean()

    cov_xy = np.sum((xb - mean_x) * (yb - mean_y))
    var_x = np.sum((xb - mean_x) ** 2)
    if var_x == 0.0:
        raise ValueError("Independent variable x has zero variance; slope undefined.")

    slope = cov_xy / var_x
    intercept = mean_y - slope * mean_x
    y_hat = slope * xb + intercept
    ss_total = np.sum((yb - mean_y) ** 2)
    ss_res = np.sum((yb - y_hat) ** 2)
    r_squared = 1 - ss_res / ss_total if ss_total != 0 else 0.0

    return float(slope), float(intercept), float(r_squared)


def _t_quantile(df: int) -> float:
    """Return two‑sided critical value for Student's t distribution."""
    if _scipy_t is not None:
        return float(_scipy_t.ppf(0.975, df))
    if df <= 30:
        return _T_TABLE_95[df]
    return 1.959963984540054


def mean_ci95(data: Sequence[float]) -> Tuple[float, float, float]:
    """95 % confidence interval for the mean using Student's *t*.

    Requires at least two data points.
    """
    n = len(data)
    if n < 2:
        raise ValueError("At least two data points are required to compute a confidence interval.")

    arr = np.asarray(data, dtype=float)
    mean = float(arr.mean())
    std = float(arr.std(ddof=1))
    se = std / np.sqrt(n)
    t_val = _t_quantile(n - 1)
    margin = t_val * se
    return mean, mean - margin, mean + margin

__all__ = ["linreg", "mean_ci95"]
