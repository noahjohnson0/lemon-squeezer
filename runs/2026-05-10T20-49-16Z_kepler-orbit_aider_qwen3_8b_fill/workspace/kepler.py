import math

def simulate(x0: float, y0: float, vx0: float, vy0: float,
             t_end: float, dt: float = 1e-3) -> tuple[float, float, float, float]:
    """Integrate a 2D Kepler problem with a fixed central mass at the origin and GM=1.0.
    Equations of motion: r̈ = -GM·r / |r|³  (vector form, both x and y couple via |r|).
    Use 4th-order Runge-Kutta (NOT Euler — Euler accumulates >5% energy drift over a single orbit).
    Returns final state (x, y, vx, vy) at simulation time t_end."""
    x, y, vx, vy = x0, y0, vx0, vy0
    time = 0.0
    while time < t_end:
        r = math.sqrt(x**2 + y**2)
        if r == 0:
            ax = 0.0
            ay = 0.0
        else:
            ax = -x / (r**3)
            ay = -y / (r**3)
        
        # Compute k1
        k1_x = vx
        k1_y = vy
        k1_vx = ax
        k1_vy = ay
        
        # Compute intermediate state for k2
        x_k2 = x + k1_x * dt/2
        y_k2 = y + k1_y * dt/2
        vx_k2 = vx + k1_vx * dt/2
        vy_k2 = vy + k1_vy * dt/2
        
        # Compute acceleration for k2
        r_k2 = math.sqrt(x_k2**2 + y_k2**2)
        if r_k2 == 0:
            ax_k2 = 0.0
            ay_k2 = 0.0
        else:
            ax_k2 = -x_k2 / (r_k2**3)
            ay_k2 = -y_k2 / (r_k2**3)
        
        # Compute k2
        k2_x = vx_k2
        k2_y = vy_k2
        k2_vx = ax_k2
        k2_vy = ay_k2
        
        # Compute intermediate state for k3
        x_k3 = x + k2_x * dt/2
        y_k3 = y + k2_y * dt/2
        vx_k3 = vx + k2_vx * dt/2
        vy_k3 = vy + k2_vy * dt/2
        
        # Compute acceleration for k3
        r_k3 = math.sqrt(x_k3**2 + y_k3**2)
        if r_k3 == 0:
            ax_k3 = 0.0
            ay_k3 = 0.0
        else:
            ax_k3 = -x_k3 / (r_k3**3)
            ay_k3 = -y_k3 / (r_k3**3)
        
        # Compute k3
        k3_x = vx_k3
        k3_y = vy_k3
        k3_vx = ax_k3
        k3_vy = ay_k3
        
        # Compute intermediate state for k4
        x_k4 = x + k3_x * dt
        y_k4 = y + k3_y * dt
        vx_k4 = vx + k3_vx * dt
        vy_k4 = vy + k3_vy * dt
        
        # Compute acceleration for k4
        r_k4 = math.sqrt(x_k4**2 + y_k4**2)
        if r_k4 == 0:
            ax_k4 = 0.0
            ay_k4 = 0.0
        else:
            ax_k4 = -x_k4 / (r_k4**3)
            ay_k4 = -y_k4 / (r_k4**3)
        
        # Compute k4
        k4_x = vx_k4
        k4_y = vy_k4
        k4_vx = ax_k4
        k4_vy = ay_k4
        
        # Update state using RK4
        x += (k1_x + 2*k2_x + 2*k3_x + k4_x) * dt / 6
        y += (k1_y + 2*k2_y + 2*k3_y + k4_y) * dt / 6
        vx += (k1_vx + 2*k2_vx + 2*k3_vx + k4_vx) * dt / 6
        vy += (k1_vy + 2*k2_vy + 2*k3_vy + k4_vy) * dt / 6
        
        time += dt
    
    return x, y, vx, vy

def total_energy(x: float, y: float, vx: float, vy: float) -> float:
    """Specific orbital energy E = ½(vx² + vy²) - GM/r where r = √(x² + y²) and GM=1.0."""
    r = math.sqrt(x**2 + y**2)
    if r == 0:
        return 0.0  # Avoid division by zero, though this case is unlikely in valid orbits
    return 0.5 * (vx**2 + vy**2) - 1.0 / r
