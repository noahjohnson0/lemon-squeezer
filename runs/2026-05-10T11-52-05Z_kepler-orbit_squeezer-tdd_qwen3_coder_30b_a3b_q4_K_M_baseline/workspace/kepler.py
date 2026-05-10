import math

def simulate(x0: float, y0: float, vx0: float, vy0: float,
             t_end: float, dt: float = 1e-3) -> tuple[float, float, float, float]:
    """Integrate a 2D Kepler problem with a fixed central mass at the origin and GM=1.0.
    Equations of motion: r̈ = -GM·r / |r|³  (vector form, both x and y couple via |r|).
    Use 4th-order Runge-Kutta (NOT Euler — Euler accumulates >5% energy drift over a single orbit).
    Returns final state (x, y, vx, vy) at simulation time t_end."""
    
    # Initialize state
    x, y = x0, y0
    vx, vy = vx0, vy0
    
    # 4th-order Runge-Kutta integration
    t = 0.0
    while t < t_end:
        # Determine actual time step to reach t_end exactly
        actual_dt = min(dt, t_end - t)
        
        # Calculate r magnitude
        r = math.sqrt(x*x + y*y)
        
        # Calculate acceleration components (using GM=1)
        ax = -x / (r*r*r)
        ay = -y / (r*r*r)
        
        # Runge-Kutta 4th order steps
        # k1
        k1_vx = ax
        k1_vy = ay
        k1_x = vx
        k1_y = vy
        
        # k2
        x2 = x + k1_x * actual_dt / 2
        y2 = y + k1_y * actual_dt / 2
        vx2 = vx + k1_vx * actual_dt / 2
        vy2 = vy + k1_vy * actual_dt / 2
        r2 = math.sqrt(x2*x2 + y2*y2)
        ax2 = -x2 / (r2*r2*r2)
        ay2 = -y2 / (r2*r2*r2)
        k2_vx = ax2
        k2_vy = ay2
        k2_x = vx2
        k2_y = vy2
        
        # k3
        x3 = x + k2_x * actual_dt / 2
        y3 = y + k2_y * actual_dt / 2
        vx3 = vx + k2_vx * actual_dt / 2
        vy3 = vy + k2_vy * actual_dt / 2
        r3 = math.sqrt(x3*x3 + y3*y3)
        ax3 = -x3 / (r3*r3*r3)
        ay3 = -y3 / (r3*r3*r3)
        k3_vx = ax3
        k3_vy = ay3
        k3_x = vx3
        k3_y = vy3
        
        # k4
        x4 = x + k3_x * actual_dt
        y4 = y + k3_y * actual_dt
        vx4 = vx + k3_vx * actual_dt
        vy4 = vy + k3_vy * actual_dt
        r4 = math.sqrt(x4*x4 + y4*y4)
        ax4 = -x4 / (r4*r4*r4)
        ay4 = -y4 / (r4*r4*r4)
        k4_vx = ax4
        k4_vy = ay4
        k4_x = vx4
        k4_y = vy4
        
        # Update state
        x = x + actual_dt * (k1_x + 2*k2_x + 2*k3_x + k4_x) / 6
        y = y + actual_dt * (k1_y + 2*k2_y + 2*k3_y + k4_y) / 6
        vx = vx + actual_dt * (k1_vx + 2*k2_vx + 2*k3_vx + k4_vx) / 6
        vy = vy + actual_dt * (k1_vy + 2*k2_vy + 2*k3_vy + k4_vy) / 6
        
        t += actual_dt
    
    return (x, y, vx, vy)

def total_energy(x: float, y: float, vx: float, vy: float) -> float:
    """Specific orbital energy E = ½(vx² + vy²) - GM/r where r = √(x² + y²) and GM=1.0."""
    r = math.sqrt(x*x + y*y)
    return 0.5 * (vx*vx + vy*vy) - 1.0 / r