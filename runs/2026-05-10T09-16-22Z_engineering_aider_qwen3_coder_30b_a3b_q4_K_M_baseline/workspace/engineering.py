def reynolds(rho: float, v: float, L: float, mu: float) -> float:
    """Reynolds number Re = rho*v*L/mu (dimensionless).
    rho: fluid density (kg/m³), v: velocity (m/s), L: characteristic length (m), mu: dynamic viscosity (Pa·s)."""
    return rho * v * L / mu

def beam_deflection_max(P: float, L: float, E: float, I: float) -> float:
    """Maximum deflection (m) of a SIMPLY-SUPPORTED beam with a point load P at midspan.
    Formula: delta_max = P * L^3 / (48 * E * I)
    P: load in Newtons; L: span in metres; E: Young's modulus (Pa); I: second moment of area (m^4)."""
    return P * L**3 / (48 * E * I)

def rc_time_constant(R: float, C: float) -> float:
    """RC time constant tau = R * C (seconds). R: ohms, C: farads."""
    return R * C

def voltage_divider(vin: float, r1: float, r2: float) -> float:
    """Voltage at the midpoint of a two-resistor divider.
    Vout = Vin * R2 / (R1 + R2). Volts; ohms; ohms."""
    return vin * r2 / (r1 + r2)
