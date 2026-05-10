import math

def simulate(x0: float, y0: float, vx0: float, vy0: float,
             t_end: float, dt: float = 1e-3) -> tuple[float, float, float, float]:
    """Integrate a 2D Kepler problem with a fixed central mass at the origin and GM=1.0.
    Equations of motion: r̈ = -GM·r / |r|³  (vector form, both x and y couple via |r|).
    Use 4th-order Runge-Kutta (NOT Euler — Euler accumulates >5% energy drift over a single orbit).
    Returns final state (x, y, vx, vy) at simulation time t_end."""

    def dydt(t: float, y: tuple[float, float, float, float]) -> tuple[float, float, float, float]:
        x, y, vx, vy = y
        r = math.sqrt(x**2 + y**2)
        ax = -x / r**3
        ay = -y / r**3
        return (vx, vy, ax, ay)

    def runge_kutta_4(y0: tuple[float, float, float, float], t0: float, dt: float) -> tuple[float, float, float, float]:
        k1 = dydt(t0, y0)
        k2 = dydt(t0 + 0.5 * dt, (y0[i] + 0.5 * dt * k1[i] for i in range(4)))
        k3 = dydt(t0 + 0.5 * dt, (y0[i] + 0.5 * dt * k2[i] for i in range(4)))
        k4 = dydt(t0 + dt, (y0[i] + dt * k3[i] for i in range(4)))

        return tuple(y0[i] + dt / 6 * sum([k[j][i] for j in range(4)]) for i in range(4))

    y = [x0, y0, vx0, vy0]
    t = 0.0
    while t < t_end:
        y = runge_kutta_4(tuple(y), t, dt)
        t += dt

    return tuple(y)

def total_energy(x: float, y: float, vx: float, vy: float) -> float:
    """Specific orbital energy E = ½(vx² + vy²) - GM/r where r = √(x² + y²) and GM=1.0."""
    r = math.sqrt(x**2 + y**2)
    return 0.5 * (vx**2 + vy**2) - 1 / r
