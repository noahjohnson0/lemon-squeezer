import math

def simulate(x0: float, y0: float, vx0: float, vy0: float,
             t_end: float, dt: float = 1e-3) -> tuple[float, float, float, float]:
    """Integrate a 2D Kepler problem with a fixed central mass at the origin and GM=1.0.
    Equations of motion: r̈ = -GM·r / |r|³  (vector form, both x and y couple via |r|).
    Use 4th-order Runge-Kutta (NOT Euler — Euler accumulates >5% energy drift over a single orbit).
    Returns final state (x, y, vx, vy) at simulation time t_end."""

    def compute_derivatives(x, y, vx, vy):
        r_squared = x**2 + y**2
        r = math.sqrt(r_squared)
        r_cubed = r_squared * r
        ax = -x / r_cubed
        ay = -y / r_cubed
        return (vx, vy, ax, ay)

    x, y, vx, vy = x0, y0, vx0, vy0
    t = 0.0
    while t < t_end:
        # Compute k1
        k1 = compute_derivatives(x, y, vx, vy)
        # Compute k2
        k2 = compute_derivatives(
            x + 0.5 * k1[0] * dt,
            y + 0.5 * k1[1] * dt,
            vx + 0.5 * k1[2] * dt,
            vy + 0.5 * k1[3] * dt
        )
        # Compute k3
        k3 = compute_derivatives(
            x + 0.5 * k2[0] * dt,
            y + 0.5 * k2[1] * dt,
            vx + 0.5 * k2[2] * dt,
            vy + 0.5 * k2[3] * dt
        )
        # Compute k4
        k4 = compute_derivatives(
            x + k3[0] * dt,
            y + k3[1] * dt,
            vx + k3[2] * dt,
            vy + k3[3] * dt
        )
        # Update state
        x += (k1[0] + 2*k2[0] + 2*k3[0] + k4[0]) / 6 * dt
        y += (k1[1] + 2*k2[1] + 2*k3[1] + k4[1]) / 6 * dt
        vx += (k1[2] + 2*k2[2] + 2*k3[2] + k4[2]) / 6 * dt
        vy += (k1[3] + 2*k2[3] + 2*k3[3] + k4[3]) / 6 * dt
        t += dt

    return (x, y, vx, vy)

def total_energy(x: float, y: float, vx: float, vy: float) -> float:
    """Specific orbital energy E = ½(vx² + vy²) - GM/r where r = √(x² + y²) and GM=1.0."""
    r = math.sqrt(x**2 + y**2)
    kinetic = 0.5 * (vx**2 + vy**2)
    potential = -1.0 / r
    return kinetic + potential
