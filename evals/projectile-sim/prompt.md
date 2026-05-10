Write `projectile.py` — a CLI tool that simulates projectile motion with quadratic air drag, using RK4 numerical integration.

Equations of motion (2D, y up, gravity g=9.81 m/s²):
```
dvx/dt = -k * |v| * vx
dvy/dt = -g - k * |v| * vy
where k = 0.5 * Cd * rho * A / m
```

CLI:
```
projectile.py <v0> <angle_deg> <Cd> <area_m2> <mass_kg> [--rho RHO] [--dt DT]
```
Defaults: `--rho 1.225` (air at sea level), `--dt 0.001`.

Behaviour:
1. Use RK4 (4th-order Runge–Kutta) — NOT Euler. (Euler accumulates large errors quickly.)
2. Run until `y` returns to 0 (after launch). Use linear interpolation between the last two steps to find the impact time precisely.
3. Print exactly three lines:
   ```
   range_m <value>
   max_height_m <value>
   flight_time_s <value>
   ```
   Each value formatted with 6 decimal places (`%.6f`).

Sanity:
- For Cd=0 (no drag): the no-drag analytic range is `v0² · sin(2θ) / g`. Your RK4 result must match this to within 0.5% for v0=50 m/s, θ=45°.
- For drag>0, range and flight time decrease vs. no-drag.

Create only `projectile.py`. Don't run it.
