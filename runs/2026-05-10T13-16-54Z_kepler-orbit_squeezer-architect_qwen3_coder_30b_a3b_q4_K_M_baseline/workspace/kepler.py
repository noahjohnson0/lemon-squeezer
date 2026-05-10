import math

def simulate(x0: float, y0: float, vx0: float, vy0: float,
             t_end: float, dt: float = 1e-3) -> tuple[float, float, float, float]:
    """Integrate a 2D Kepler problem with a fixed central mass at the origin and GM=1.0.
    Equations of motion: r̈ = -GM·r / |r|³  (vector form, both x and y couple via |r|).
    Use 4th-order Runge-Kutta (NOT Euler — Euler accumulates >5% energy drift over a single orbit).
    Returns final state (x, y, vx, vy) at simulation time t_end."""
    
    # Constant GM
    GM = 1.0
    
    # Initialize state vector
    x, y, vx, vy = x0, y0, vx0, vy0
    
    # Check for invalid initial conditions
    r = math.sqrt(x**2 + y**2)
    if r == 0.0:
        raise ValueError("Initial position cannot be at the origin (0, 0).")
    
    if dt <= 0:
        raise ValueError("Time step dt must be positive.")
        
    t = 0.0
    while t < t_end:
        # Compute the step size for this iteration
        dt_step = min(dt, t_end - t)
        
        # Define the RHS function for the ODE
        def f(state):
            x, y, vx, vy = state
            r = math.sqrt(x**2 + y**2)
            if r == 0:
                # Avoid division by zero; in a physical context this shouldn't happen
                raise ValueError("Encountered zero distance during integration.")
            ax = -GM * x / (r**3)
            ay = -GM * y / (r**3)
            return [vx, vy, ax, ay]
        
        # 4th-order Runge-Kutta step
        k1 = f([x, y, vx, vy])
        k2 = f([x + dt_step * k1[0] / 2, y + dt_step * k1[1] / 2, 
                vx + dt_step * k1[2] / 2, vy + dt_step * k1[3] / 2])
        k3 = f([x + dt_step * k2[0] / 2, y + dt_step * k2[1] / 2, 
                vx + dt_step * k2[2] / 2, vy + dt_step * k2[3] / 2])
        k4 = f([x + dt_step * k3[0], y + dt_step * k3[1], 
                vx + dt_step * k3[2], vy + dt_step * k3[3]])
        
        # Update state
        x += dt_step * (k1[0] + 2 * k2[0] + 2 * k3[0] + k4[0]) / 6
        y += dt_step * (k1[1] + 2 * k2[1] + 2 * k3[1] + k4[1]) / 6
        vx += dt_step * (k1[2] + 2 * k2[2] + 2 * k3[2] + k4[2]) / 6
        vy += dt_step * (k1[3] + 2 * k2[3] + 2 * k3[3] + k4[3]) / 6
        
        # Update time
        t += dt_step
        
    return (x, y, vx, vy)


def total_energy(x: float, y: float, vx: float, vy: float) -> float:
    """Specific orbital energy E = ½(vx² + vy²) - GM/r where r = √(x² + y²) and GM=1.0."""
    r = math.sqrt(x**2 + y**2)
    v_squared = vx**2 + vy**2
    return 0.5 * v_squared - 1.0 / r