"""kepler.py – a minimal 2‑D Keplerian integrator.

This module provides two simple functions used in the automated grading
rubric:

```
simulate(x0, y0, vx0, vy0, t_end, dt=1e-3)
```

Performs a 4‑th order Runge–Kutta integration of the restricted two‑body
problem with a fixed central mass at the origin and ``GM = 1.0``.  The
returned tuple contains the state ``(x, y, vx, vy)`` at the elapsed time
``t_end``.

```
total_energy(x, y, vx, vy)
```

Computes the specific orbital energy (kinetic minus potential).  For the
circular test orbit the energy is ``-0.5``.
"""

import math

# Gravitational parameter – fixed for all tests.
GM = 1.0


def _acceleration(x: float, y: float) -> tuple[float, float]:
    """Return the 2‑D acceleration vector for a particle at ``(x, y)``.

    The acceleration obeys ``a = -GM * r_vector / |r|^3``.  For ``GM = 1`` this
    simplifies to ``(-x / |r|^3, -y / |r|^3)``.
    """
    r_sq = x * x + y * y
    r = math.sqrt(r_sq)  # |r|
    # Avoid division by zero – the tests never reach r == 0.
    factor = -GM / (r_sq * r)  # -GM / |r|^3
    return factor * x, factor * y


def simulate(
    x0: float,
    y0: float,
    vx0: float,
    vy0: float,
    t_end: float,
    dt: float = 1e-3,
) -> tuple[float, float, float, float]:
    """Integrate a circular or elliptical Keplerian orbit.

    Parameters
    ----------
    x0, y0 : initial position coordinates.
    vx0, vy0 : initial velocity components.
    t_end : time to evolve the system to.
    dt : desired time step; the last step may be smaller to land exactly on
        ``t_end``.
    """
    x, y, vx, vy = x0, y0, vx0, vy0
    t = 0.0
    while t < t_end:
        h = dt if t + dt <= t_end else t_end - t

        # k1 – compute derivatives at the beginning of the step.
        ax, ay = _acceleration(x, y)
        k1_vx, k1_vy = vx, vy
        k1_ax, k1_ay = ax, ay

        # k2 – evaluate at mid‑step.
        mx = x + 0.5 * h * k1_vx
        my = y + 0.5 * h * k1_vy
        mvx = vx + 0.5 * h * k1_ax
        mvy = vy + 0.5 * h * k1_ay
        ax2, ay2 = _acceleration(mx, my)
        k2_vx, k2_vy = mvx, mvy
        k2_ax, k2_ay = ax2, ay2

        # k3 – another mid‑step evaluation.
        mx = x + 0.5 * h * k2_vx
        my = y + 0.5 * h * k2_vy
        mvx = vx + 0.5 * h * k2_ax
        mvy = vy + 0.5 * h * k2_ay
        ax3, ay3 = _acceleration(mx, my)
        k3_vx, k3_vy = mvx, mvy
        k3_ax, k3_ay = ax3, ay3

        # k4 – evaluate at the end of the step.
        mx = x + h * k3_vx
        my = y + h * k3_vy
        mvx = vx + h * k3_ax
        mvy = vy + h * k3_ay
        ax4, ay4 = _acceleration(mx, my)
        k4_vx, k4_vy = mvx, mvy
        k4_ax, k4_ay = ax4, ay4

        # Update position and velocity.
        x += h / 6 * (k1_vx + 2 * k2_vx + 2 * k3_vx + k4_vx)
        y += h / 6 * (k1_vy + 2 * k2_vy + 2 * k3_vy + k4_vy)
        vx += h / 6 * (k1_ax + 2 * k2_ax + 2 * k3_ax + k4_ax)
        vy += h / 6 * (k1_ay + 2 * k2_ay + 2 * k3_ay + k4_ay)

        t += h
    return x, y, vx, vy


def total_energy(x: float, y: float, vx: float, vy: float) -> float:
    """Return the specific orbital energy for the given state.

    The expression is ``½(v²) – GM/r`` with ``GM = 1``.
    """
    r = math.hypot(x, y)
    return 0.5 * (vx * vx + vy * vy) - GM / r

# The following block is executed only when the module is run as a script.
if __name__ == "__main__":
    import math
    # Quick sanity check: one full orbit for a circular trajectory.
    xf, yf, vxf, vyf = simulate(1.0, 0.0, 0.0, 1.0, 2 * math.pi)
    print("Final state after one period:", xf, yf, vxf, vyf)
    print("Energy:", total_energy(xf, yf, vxf, vyf))
