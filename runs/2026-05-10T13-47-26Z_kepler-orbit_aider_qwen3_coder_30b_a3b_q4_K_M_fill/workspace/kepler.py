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
    
    # Time integration using 4th-order Runge-Kutta
    t = 0.0
    while t < t_end:
        # Limit step size to reach exactly t_end
        current_dt = min(dt, t_end - t)
        
        # Calculate r magnitude
        r = math.sqrt(x*x + y*y)
        
        # Calculate acceleration components (GM = 1.0)
        ax = -x / (r*r*r)
        ay = -y / (r*r*r)
        
        # RK4 steps
        k1_vx = ax
        k1_vy = ay
        
        k1_x = vx
        k1_y = vy
        
        # Intermediate values
        x1 = x + k1_x * current_dt / 2
        y1 = y + k1_y * current_dt / 2
        vx1 = vx + k1_vx * current_dt / 2
        vy1 = vy + k1_vy * current_dt / 2
        
        # Calculate r for intermediate values
        r1 = math.sqrt(x1*x1 + y1*y1)
        
        # Acceleration at intermediate point
        ax1 = -x1 / (r1*r1*r1)
        ay1 = -y1 / (r1*r1*r1)
        
        k2_vx = ax1
        k2_vy = ay1
        
        k2_x = vx1
        k2_y = vy1
        
        # Second intermediate values
        x2 = x + k2_x * current_dt / 2
        y2 = y + k2_y * current_dt / 2
        vx2 = vx + k2_vx * current_dt / 2
        vy2 = vy + k2_vy * current_dt / 2
        
        # Calculate r for second intermediate values
        r2 = math.sqrt(x2*x2 + y2*y2)
        
        # Acceleration at second intermediate point
        ax2 = -x2 / (r2*r2*r2)
        ay2 = -y2 / (r2*r2*r2)
        
        k3_vx = ax2
        k3_vy = ay2
        
        k3_x = vx2
        k3_y = vy2
        
        # Third intermediate values
        x3 = x + k3_x * current_dt
        y3 = y + k3_y * current_dt
        vx3 = vx + k3_vx * current_dt
        vy3 = vy + k3_vy * current_dt
        
        # Calculate r for third intermediate values
        r3 = math.sqrt(x3*x3 + y3*y3)
        
        # Acceleration at third intermediate point
        ax3 = -x3 / (r3*r3*r3)
        ay3 = -y3 / (r3*r3*r3)
        
        k4_vx = ax3
        k4_vy = ay3
        
        k4_x = vx3
        k4_y = vy3
        
        # Update position and velocity using RK4
        x = x + (k1_x + 2*k2_x + 2*k3_x + k4_x) * current_dt / 6
        y = y + (k1_y + 2*k2_y + 2*k3_y + k4_y) * current_dt / 6
        vx = vx + (k1_vx + 2*k2_vx + 2*k3_vx + k4_vx) * current_dt / 6
        vy = vy + (k1_vy + 2*k2_vy + 2*k3_vy + k4_vy) * current_dt / 6
        
        t += current_dt
    
    return (x, y, vx, vy)


def total_energy(x: float, y: float, vx: float, vy: float) -> float:
    """Specific orbital energy E = ½(vx² + vy²) - GM/r where r = √(x² + y²) and GM=1.0."""
    r = math.sqrt(x*x + y*y)
    return 0.5 * (vx*vx + vy*vy) - 1.0 / r
