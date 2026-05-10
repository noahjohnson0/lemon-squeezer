import math

def simulate(x0: float, y0: float, vx0: float, vy0: float,
             t_end: float, dt: float = 1e-3) -> tuple[float, float, float, float]:
    """Integrate a 2D Kepler problem with a fixed central mass at the origin and GM=1.0.
    Equations of motion: r̈ = -GM·r / |r|³  (vector form, both x and y couple via |r|).
    Use 4th-order Runge-Kutta (NOT Euler — Euler accumulates >5% energy drift over a single orbit).
    Returns final state (x, y, vx, vy) at simulation time t_end."""
    
    # Initial conditions
    x, y = x0, y0
    vx, vy = vx0, vy0
    
    # 4th-order Runge-Kutta integration
    t = 0.0
    while t < t_end - 1e-12:  # account for floating-point precision
        # Step size
        h = min(dt, t_end - t)
        
        # Compute current r
        r = math.sqrt(x*x + y*y)
        
        # Compute acceleration components
        ax = -x / (r*r*r)
        ay = -y / (r*r*r)
        
        # RK4 steps
        k1x = vx
        k1y = vy
        k1vx = ax
        k1vy = ay
        
        k2x = vx + 0.5 * h * k1vx
        k2y = vy + 0.5 * h * k1vy
        r2 = math.sqrt((x + 0.5 * h * k1x)**2 + (y + 0.5 * h * k1y)**2)
        k2vx = - (x + 0.5 * h * k1x) / (r2*r2*r2)
        k2vy = - (y + 0.5 * h * k1y) / (r2*r2*r2)
        
        k3x = vx + 0.5 * h * k2vx
        k3y = vy + 0.5 * h * k2vy
        r3 = math.sqrt((x + 0.5 * h * k2x)**2 + (y + 0.5 * h * k2y)**2)
        k3vx = - (x + 0.5 * h * k2x) / (r3*r3*r3)
        k3vy = - (y + 0.5 * h * k2y) / (r3*r3*r3)
        
        k4x = vx + h * k3vx
        k4y = vy + h * k3vy
        r4 = math.sqrt((x + h * k3x)**2 + (y + h * k3y)**2)
        k4vx = - (x + h * k3x) / (r4*r4*r4)
        k4vy = - (y + h * k3y) / (r4*r4*r4)
        
        # Update state
        x += h * (k1x + 2*k2x + 2*k3x + k4x) / 6
        y += h * (k1y + 2*k2y + 2*k3y + k4y) / 6
        vx += h * (k1vx + 2*k2vx + 2*k3vx + k4vx) / 6
        vy += h * (k1vy + 2*k2vy + 2*k3vy + k4vy) / 6
        
        t += h

    return (x, y, vx, vy)

def total_energy(x: float, y: float, vx: float, vy: float) -> float:
    """Specific orbital energy E = ½(vx² + vy²) - GM/r where r = √(x² + y²) and GM=1.0."""
    r = math.sqrt(x*x + y*y)
    return 0.5 * (vx*vx + vy*vy) - 1.0 / r