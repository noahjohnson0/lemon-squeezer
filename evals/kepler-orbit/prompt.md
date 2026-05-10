Write `kepler.py` exporting a 2D two-body orbital integrator.

```python
def simulate(x0: float, y0: float, vx0: float, vy0: float,
             t_end: float, dt: float = 1e-3) -> tuple[float, float, float, float]:
    """Integrate a 2D Kepler problem with a fixed central mass at the origin and GM=1.0.
    Equations of motion: r̈ = -GM·r / |r|³  (vector form, both x and y couple via |r|).
    Use 4th-order Runge-Kutta (NOT Euler — Euler accumulates >5% energy drift over a single orbit).
    Returns final state (x, y, vx, vy) at simulation time t_end."""

def total_energy(x: float, y: float, vx: float, vy: float) -> float:
    """Specific orbital energy E = ½(vx² + vy²) - GM/r where r = √(x² + y²) and GM=1.0."""
```

Sanity checks the rubric will run:
- Circular orbit: simulate(1, 0, 0, 1, 2π, 1e-3) returns ≈ (1, 0, 0, 1) (back to start, period=2π).
- Half-orbit: simulate(1, 0, 0, 1, π) returns ≈ (-1, 0, 0, -1).
- Energy conservation: total_energy(1, 0, 0, 1) == -0.5 exactly. After a full orbit, energy must drift by < 1e-3.

Pure stdlib (math). No numpy required (you may use it).

Create only `kepler.py`. Don't run it.
