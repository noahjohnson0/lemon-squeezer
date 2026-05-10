
# aider chat started at 2026-05-10 09:46:13

> You can skip this check with --no-gitignore  
> Add .aider* to .gitignore (recommended)? (Y)es/(N)o [Yes]: y  
> Added .aider* to .gitignore  
> /Users/noahjohnson0/.local/bin/aider --model ollama_chat/gpt-oss:20b --no-auto-commits --no-show-model-warnings --no-stream --no-pretty --no-analytics --yes-always --message-file /Users/noahjohnson0/repos/lemon-squeezer/evals/kepler-orbit/prompt.md  
> Aider v0.86.2  
> Model: ollama_chat/gpt-oss:20b with whole edit format  
> Git repo: .git with 0 files  
> Repo-map: using 4096 tokens, auto refresh  

#### Write `kepler.py` exporting a 2D two-body orbital integrator.  
####   
#### ```python  
#### def simulate(x0: float, y0: float, vx0: float, vy0: float,  
####              t_end: float, dt: float = 1e-3) -> tuple[float, float, float, float]:  
####     """Integrate a 2D Kepler problem with a fixed central mass at the origin and GM=1.0.  
####     Equations of motion: r̈ = -GM·r / |r|³  (vector form, both x and y couple via |r|).  
####     Use 4th-order Runge-Kutta (NOT Euler — Euler accumulates >5% energy drift over a single orbit).  
####     Returns final state (x, y, vx, vy) at simulation time t_end."""  
####   
#### def total_energy(x: float, y: float, vx: float, vy: float) -> float:  
####     """Specific orbital energy E = ½(vx² + vy²) - GM/r where r = √(x² + y²) and GM=1.0."""  
#### ```  
####   
#### Sanity checks the rubric will run:  
#### - Circular orbit: simulate(1, 0, 0, 1, 2π, 1e-3) returns ≈ (1, 0, 0, 1) (back to start, period=2π).  
#### - Half-orbit: simulate(1, 0, 0, 1, π) returns ≈ (-1, 0, 0, -1).  
#### - Energy conservation: total_energy(1, 0, 0, 1) == -0.5 exactly. After a full orbit, energy must drift by < 1e-3.  
####   
#### Pure stdlib (math). No numpy required (you may use it).  
####   
#### Create only `kepler.py`. Don't run it.  

kepler.py
```
"""
2D Keplerian orbital integrator using a fixed central mass at the origin
with GM = 1.0.  The integrator uses a classic 4th‑order Runge–Kutta
scheme and is fully self‑contained (no external dependencies beyond the
standard library).

Functions
---------
simulate(x0, y0, vx0, vy0, t_end, dt=1e-3)
    Integrate the equations of motion from the initial state
    (x0, y0, vx0, vy0) until time ``t_end`` using a fixed step size
    ``dt``.  Returns the final state (x, y, vx, vy).

total_energy(x, y, vx, vy)
    Compute the specific orbital energy
    E = ½(vx² + vy²) – GM / r   with GM = 1.0.
"""

from __future__ import annotations

import math
from typing import Tuple

# Gravitational constant times central mass
GM: float = 1.0


def _acceleration(x: float, y: float) -> Tuple[float, float]:
    """
    Compute the gravitational acceleration at position (x, y).

    Parameters
    ----------
    x, y : float
        Cartesian coordinates of the particle.

    Returns
    -------
    ax, ay : tuple[float, float]
        Acceleration components.
    """
    r_sq = x * x + y * y
    # Avoid division by zero; for r == 0 the acceleration is undefined.
    if r_sq == 0.0:
        raise ValueError("Position at the origin leads to singular acceleration.")
    r = math.sqrt(r_sq)
    inv_r3 = 1.0 / (r_sq * r)  # 1 / r³
    ax = -GM * x * inv_r3
    ay = -GM * y * inv_r3
    return ax, ay


def _derivatives(state: Tuple[float, float, float, float]) -> Tuple[float, float, float, float]:
    """
    Compute the time derivative of the state vector.

    Parameters
    ----------
    state : tuple[float, float, float, float]
        Current state (x, y, vx, vy).

    Returns
    -------
    dx, dy, dvx, dvy : tuple[float, float, float, float]
        Derivatives of the state.
    """
    x, y, vx, vy = state
    ax, ay = _acceleration(x, y)
    return vx, vy, ax, ay


def simulate(
    x0: float,
    y0: float,
    vx0: float,
    vy0: float,
    t_end: float,
    dt: float = 1e-3,
) -> Tuple[float, float, float, float]:
    """
    Integrate a 2‑D Kepler problem with a fixed central mass at the origin
    and GM = 1.0 using a 4th‑order Runge–Kutta scheme.

    Parameters
    ----------
    x0, y0 : float
        Initial position coordinates.
    vx0, vy0 : float
        Initial velocity components.
    t_end : float
        Final simulation time.
    dt : float, optional
        Time step for the integration (default 1e-3).

    Returns
    -------
    x, y, vx, vy : tuple[float, float, float, float]
        State at time ``t_end``.
    """
    # Current state
    state = (x0, y0, vx0, vy0)
    t = 0.0

    # Main integration loop
    while t < t_end:
        # Adjust last step to land exactly on t_end
        step = dt if t + dt <= t_end else t_end - t

        # RK4 coefficients
        k1 = _derivatives(state)

        # Helper to add scaled vectors
        def _add(state_vec, k_vec, scale):
            return tuple(s + scale * k for s, k in zip(state_vec, k_vec))

        k2 = _derivatives(_add(state, k1, step / 2.0))
        k3 = _derivatives(_add(state, k2, step / 2.0))
        k4 = _derivatives(_add(state, k3, step))

        # Update state
        state = tuple(
            s + (step / 6.0) * (k1_i + 2.0 * k2_i + 2.0 * k3_i + k4_i)
            for s, k1_i, k2_i, k3_i, k4_i in zip(state, k1, k2, k3, k4)
        )

        t += step

    return state


def total_energy(x: float, y: float, vx: float, vy: float) -> float:
    """
    Compute the specific orbital energy for a particle in the Kepler
    potential with GM = 1.0.

    Parameters
    ----------
    x, y : float
        Position coordinates.
    vx, vy : float
        Velocity components.

    Returns
    -------
    E : float
        Specific orbital energy.
    """
    r = math.hypot(x, y)
    if r == 0.0:
        raise ValueError("Energy undefined at the origin.")
    kinetic = 0.5 * (vx * vx + vy * vy)
    potential = -GM / r
    return kinetic + potential
```

> Tokens: 1.1k sent, 1.5k received.  
> kepler.py  
> Create new file? (Y)es/(N)o [Yes]: y  
> Applied edit to kepler.py  
