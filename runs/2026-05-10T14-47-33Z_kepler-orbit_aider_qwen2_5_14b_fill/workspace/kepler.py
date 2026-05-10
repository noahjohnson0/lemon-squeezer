import math

def runge_kutta(x0: float, y0: float, vx0: float, vy0: float,
                t_end: float, dt: float = 1e-3) -> tuple[float, float, float, float]:
    """Integrate a 2D Kepler problem with a fixed central mass at the origin and GM=1.0.
    Equations of motion: r̈ = -GM·r / |r|³  (vector form, both x and y couple via |r|).
    Use 4th-order Runge-Kutta (NOT Euler — Euler accumulates >5% energy drift over a single orbit).
    Returns final state (x, y, vx, vy) at simulation time t_end."""

    def acceleration(x: float, y: float):
        r = math.sqrt(x**2 + y**2)
        return -1.0 / r**3 * (x, y)

    x, y, vx, vy = x0, y0, vx0, vy0
    t = 0

    while t < t_end:
        k1_x = dt * vx
        k1_y = dt * vy
        ax, ay = acceleration(x, y)
        k1_vx = dt * ax
        k1_vy = dt * ay

        k2_x = dt * (vx + 0.5 * k1_vx)
        k2_y = dt * (vy + 0.5 * k1_vy)
        ax, ay = acceleration(x + 0.5 * k1_x, y + 0.5 * k1_y)
        k2_vx = dt * ax
        k2_vy = dt * ay

        k3_x = dt * (vx + 0.5 * k2_vx)
        k3_y = dt * (vy + 0.5 * k2_vy)
        ax, ay = acceleration(x + 0.5 * k2_x, y + 0.5 * k2_y)
        k3_vx = dt * ax
        k3_vy = dt * ay

        k4_x = dt * (vx + k3_vx)
        k4_y = dt * (vy + k3_vy)
        ax, ay = acceleration(x + k3_x, y + k3_y)
        k4_vx = dt * ax
        k4_vy = dt * ay

        x += (k1_x + 2.0 * (k2_x + k3_x) + k4_x) / 6.0
        y += (k1_y + 2.0 * (k2_y + k3_y) + k4_y) / 6.0
        vx += (k1_vx + 2.0 * (k2_vx + k3_vx) + k4_vx) / 6.0
        vy += (k1_vy + 2.0 * (k2_vy + k3_vy) + k4_vy) / 6.0

        t += dt

    return x, y, vx, vy


def total_energy(x: float, y: float, vx: float, vy: float) -> float:
    """Specific orbital energy E = ½(vx² + vy²) - GM/r where r = √(x² + y²) and GM=1.0."""
    r = math.sqrt(x**2 + y**2)
    return 0.5 * (vx**2 + vy**2) - 1 / r
