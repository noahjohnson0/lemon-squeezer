#!/usr/bin/env python3
"""
Simulation of projectile motion with quadratic air drag using RK4.

Usage:
    projectile.py <v0> <angle_deg> <Cd> <area_m2> <mass_kg> [--rho RHO] [--dt DT]

Outputs:
    range_m <value>
    max_height_m <value>
    flight_time_s <value>

All values are printed with 6 decimal places.
"""

import argparse
import math
import sys

# ---------- Constants ----------
GRAVITY = 9.81  # m/s^2

# ---------- Helper functions ----------

def parse_arguments():
    parser = argparse.ArgumentParser(description="Projectile motion with air drag (quadratic).")
    parser.add_argument("v0", type=float, help="Initial speed (m/s)")
    parser.add_argument("angle_deg", type=float, help="Launch angle in degrees (up)")
    parser.add_argument("Cd", type=float, help="Drag coefficient")
    parser.add_argument("area_m2", type=float, help="Cross‑sectional area (m^2)")
    parser.add_argument("mass_kg", type=float, help="Mass of the projectile (kg)")
    parser.add_argument("--rho", type=float, default=1.225, help="Air density (kg/m^3), default 1.225 @ sea level")
    parser.add_argument("--dt", type=float, default=0.001, help="Time step for RK4 integration (s), default 0.001")
    return parser.parse_args()


def derivative(state, k):
    """Return derivative [dx, dy, dvx, dvy] for given state [x, y, vx, vy]."""
    x, y, vx, vy = state
    v = math.hypot(vx, vy)
    ax = -k * v * vx
    ay = -GRAVITY - k * v * vy
    return [vx, vy, ax, ay]


def rk4_step(state, dt, k):
    k1 = derivative(state, k)
    state_k1 = [state[i] + dt * k1[i] * 0.5 for i in range(4)]
    k2 = derivative(state_k1, k)
    state_k2 = [state[i] + dt * k2[i] * 0.5 for i in range(4)]
    k3 = derivative(state_k2, k)
    state_k3 = [state[i] + dt * k3[i] for i in range(4)]
    k4 = derivative(state_k3, k)
    new_state = [state[i] + dt * (k1[i] + 2 * k2[i] + 2 * k3[i] + k4[i]) / 6.0 for i in range(4)]
    return new_state


def simulate(v0, angle_deg, Cd, area, mass, rho, dt):
    # Compute drag coefficient k
    k = 0.5 * Cd * rho * area / mass

    angle_rad = math.radians(angle_deg)
    vx0 = v0 * math.cos(angle_rad)
    vy0 = v0 * math.sin(angle_rad)

    # Initial state
    state = [0.0, 0.0, vx0, vy0]
    t = 0.0
    prev_state = state[:]
    max_height = state[1]

    while True:
        # Advance one step
        state = rk4_step(state, dt, k)
        t += dt

        # Update max height
        if state[1] > max_height:
            max_height = state[1]

        # Check for ground crossing (y <= 0)
        if state[1] <= 0.0:
            # Linear interpolation to find more accurate ground intersection
            x0, y0, _, _ = prev_state
            x1, y1, _, _ = state
            # Handle the case where previous y was also <=0 (should not happen except first step)
            if y1 == y0:
                # Avoid division by zero; take the earlier state
                t_ground = t - dt
                x_ground = x0
            else:
                frac = -y0 / (y1 - y0)  # proportion between 0 and 1
                t_ground = t - dt + frac * dt
                x_ground = x0 + frac * (x1 - x0)
            return x_ground, max_height, t_ground

        prev_state = state[:]


def main():
    args = parse_arguments()

    try:
        rng, maxh, ft = simulate(
            args.v0,
            args.angle_deg,
            args.Cd,
            args.area_m2,
            args.mass_kg,
            args.rho,
            args.dt,
        )
    except Exception as e:
        print(f"Error during simulation: {e}", file=sys.stderr)
        sys.exit(1)

    # Output results with 6 decimal places
    print("range_m %.6f" % rng)
    print("max_height_m %.6f" % maxh)
    print("flight_time_s %.6f" % ft)


if __name__ == "__main__":
    main()

