"""
SIR epidemic model with RK4 integration.

Functions
---------
sir_rk4(S0, I0, R0, beta, gamma, t_end, dt=0.1)
    Integrate the SIR equations from t=0 to t=t_end using the
    classical 4th‑order Runge–Kutta method.

peak_infection_day(history)
    Return the time and infected count at which the infected
    population reaches its maximum.
"""

from __future__ import annotations
from typing import List, Tuple


def _derivatives(S: float, I: float, R: float, beta: float, gamma: float, N: float) -> Tuple[float, float, float]:
    """
    Compute the derivatives dS/dt, dI/dt, dR/dt for the SIR model.
    """
    dS = -beta * S * I / N
    dI = beta * S * I / N - gamma * I
    dR = gamma * I
    return dS, dI, dR


def sir_rk4(
    S0: float,
    I0: float,
    R0: float,
    beta: float,
    gamma: float,
    t_end: float,
    dt: float = 0.1,
) -> List[Tuple[float, float, float, float]]:
    """
    Integrate the SIR model using the classical 4th‑order Runge–Kutta method.

    Parameters
    ----------
    S0, I0, R0 : float
        Initial susceptible, infected and recovered populations.
    beta : float
        Transmission rate.
    gamma : float
        Recovery rate.
    t_end : float
        Final time to integrate to (inclusive).
    dt : float, optional
        Time step for the integration. Default is 0.1.

    Returns
    -------
    history : list of tuples
        Each tuple is (t, S, I, R). The list starts with t=0 and ends
        with the first time step that is >= t_end.
    """
    if dt <= 0:
        raise ValueError("dt must be positive")

    N = S0 + I0 + R0
    history: List[Tuple[float, float, float, float]] = []

    t = 0.0
    S, I, R = S0, I0, R0
    history.append((t, S, I, R))

    # Main integration loop
    while t < t_end - 1e-12:
        # Compute k1
        dS1, dI1, dR1 = _derivatives(S, I, R, beta, gamma, N)

        # Compute k2
        S2 = S + 0.5 * dt * dS1
        I2 = I + 0.5 * dt * dI1
        R2 = R + 0.5 * dt * dR1
        dS2, dI2, dR2 = _derivatives(S2, I2, R2, beta, gamma, N)

        # Compute k3
        S3 = S + 0.5 * dt * dS2
        I3 = I + 0.5 * dt * dI2
        R3 = R + 0.5 * dt * dR2
        dS3, dI3, dR3 = _derivatives(S3, I3, R3, beta, gamma, N)

        # Compute k4
        S4 = S + dt * dS3
        I4 = I + dt * dI3
        R4 = R + dt * dR3
        dS4, dI4, dR4 = _derivatives(S4, I4, R4, beta, gamma, N)

        # Update state
        S += (dt / 6.0) * (dS1 + 2 * dS2 + 2 * dS3 + dS4)
        I += (dt / 6.0) * (dI1 + 2 * dI2 + 2 * dI3 + dI4)
        R += (dt / 6.0) * (dR1 + 2 * dR2 + 2 * dR3 + dR4)

        # Numerical drift correction: enforce conservation
        total = S + I + R
        if abs(total - N) > 1e-6:
            # Scale to keep total exactly N
            scale = N / total
            S *= scale
            I *= scale
            R *= scale

        t += dt
        history.append((t, S, I, R))

    # Ensure the final time is exactly t_end if it was not reached
    if abs(history[-1][0] - t_end) > 1e-12:
        # Interpolate linearly to t_end
        t_last, S_last, I_last, R_last = history[-1]
        t_prev, S_prev, I_prev, R_prev = history[-2]
        # Linear interpolation factor
        f = (t_end - t_prev) / (t_last - t_prev)
        S_end = S_prev + f * (S_last - S_prev)
        I_end = I_prev + f * (I_last - I_prev)
        R_end = R_prev + f * (R_last - R_prev)
        history.append((t_end, S_end, I_end, R_end))

    return history


def peak_infection_day(history: List[Tuple[float, float, float, float]]) -> Tuple[float, float]:
    """
    Find the time and infected count at which the infected population
    reaches its maximum.

    Parameters
    ----------
    history : list of tuples
        Output from sir_rk4.

    Returns
    -------
    (t_peak, I_peak) : tuple[float, float]
        Time and infected count at the peak.
    """
    if not history:
        raise ValueError("History is empty")

    t_peak, _, I_peak, _ = max(history, key=lambda x: x[2])
    return t_peak, I_peak
