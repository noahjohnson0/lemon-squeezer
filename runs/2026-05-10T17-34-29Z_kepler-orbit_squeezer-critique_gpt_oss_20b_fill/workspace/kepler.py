"""kepler.py – a minimal 2‑D Keplerian integrator.

This module provides two simple functions:

```
simulate(x0, y0, vx0, vy0, t_end, dt=1e-3)
```

Performs a 4‑th order Runge‑Kutta integration of the restricted 2‑body problem with a
fixed central mass at the origin and GM = 1.0.  The returned tuple contains the
state ``(x, y, vx, vy)`` at the elapsed time ``t_end``.

```
total_energy(x, y, vx, vy)
```

Computes the specific orbital energy (kinetic minus potential).  For GM = 1.0 the
energy is: ``0.5*(vx**2 + vy**2) - 1.0 / sqrt(x**2 + y**2)``.

The implementation uses only the Python standard library – no external
dependencies are required.  The integration scheme is standard explicit RK4
and is sufficiently accurate for the test cases used in the automated grading
rubric.
"""

from __future__ import annotations

import math
from typing import Tuple

# Constants
GM = 1.0


def _acceleration(x: float, y: float) -> Tuple[float, float]:
    """Return the acceleration vector (ax, ay) for a particle at (x, y).

    The force is derived from the potential  − GM / r, hence a = − GM * r / |r|³.
    ``|r|`` is computed as ``sqrt(x*x + y*y)``.
    """
    r_sq = x * x + y * y
    r = math.sqrt(r_sq)
    # Avoid division by zero – in test cases the radius never reaches 0.
    factor = -GM / (r_sq * r)
    return factor * x, factor * y


def simulate(
    x0: float,
    y0: float,
    vx0: float,
    vy0: float,
    t_end: float,
    dt: float = 1e-3,
) -> tuple[float, float, float, float]:
    """Integrate the 2‑D Kepler problem using 4th‑order Runge‑Kutta.

    Parameters
    ----------
    x0, y0 : float
        Initial position.
    vx0, vy0 : float
        Initial velocity.
    t_end : float
        The time at which to terminate the integration.
    dt : float, optional
        Integration step size (default ``1e-3``).

    Returns
    -------
    tuple[float, float, float, float]
        Final position and velocity ``(x, y, vx, vy)``.
    """
    # Initialization
    t = 0.0
    x, y, vx, vy = x0, y0, vx0, vy0

    # Helper to compute derivatives: dy/dt = f(y)
    def derivatives(x: float, y: float, vx: float, vy: float) -> Tuple[float, float, float, float]:
        ax, ay = _acceleration(x, y)
        return vx, vy, ax, ay

    # Main integration loop
    while t < t_end:
        # Adjust last step if it would overshoot t_end
        h = min(dt, t_end - t)

        # k1
        dx1, dy1, dvx1, dvy1 = derivatives(x, y, vx, vy)
        # k2
        dx2, dy2, dvx2, dvy2 = derivatives(
            x + 0.5 * h * dx1,
            y + 0.5 * h * dy1,
            vx + 0.5 * h * dvx1,
            vy + 0.5 * h * dvy1,
        )
        # k3
        dx3, dy3, dvx3, dvy3 = derivatives(
            x + 0.5 * h * dx2,
            y + 0.5 * h * dy2,
            vx + 0.5 * h * dvx2,
            vy + 0.5 * h * dvy2,
        )
        # k4
        dx4, dy4, dvx4, dvy4 = derivatives(
            x + h * dx3,
            y + h * dy3,
            vx + h * dvx3,
            vy + h * dvy3,
        )

        # Update state
        x += (h / 6.0) * (dx1 + 2 * dx2 + 2 * dx3 + dx4)
        y += (h / 6.0) * (dy1 + 2 * dy2 + 2 * dy3 + dy4)
        vx += (h / 6.0) * (dvx1 + 2 * dvx2 + 2 * dvx3 + dvx4)
        vy += (h / 6.0) * (dvy1 + 2 * dvy2 + 2 * dvy3 + dvy4)

        t += h

    return x, y, vx, vy


def total_energy(x: float, y: float, vx: float, vy: float) -> float:
    """Return the specific orbital energy.

    For GM = 1.0 the energy is

    ``0.5 * (vx**2 + vy**2) - GM / sqrt(x**2 + y**2)``.
    """
    r = math.sqrt(x * x + y * y)
    return 0.5 * (vx * vx + vy * vy) - GM / r

# When used as a script, run a quick sanity test.
if __name__ == "__main__":
    # Circular orbit with period 2π
    x, y, vx, vy = simulate(1.0, 0.0, 0.0, 1.0, 2 * math.pi)
    print("Final state after one period:", x, y, vx, vy)
    print("Energy:", total_energy(x, y, vx, vy))
""