#!/usr/bin/env python3
import sys
import math
import argparse

# Constants
GRAVITY = 9.81  # m/s^2

def rk4_step(state, dt, k):
    """
    Perform one RK4 step for the projectile state.
    state: [x, y, vx, vy]
    k: drag coefficient factor
    Returns new state.
    """
    x, y, vx, vy = state
    v_mag = math.hypot(vx, vy)

    def derivatives(vx_, vy_):
        v_mag_ = math.hypot(vx_, vy_)
        dvx = -k * v_mag_ * vx_
        dvy = -GRAVITY - k * v_mag_ * vy_
        return dvx, dvy

    # k1
    dvx1, dvy1 = derivatives(vx, vy)
    vx1 = vx
    vy1 = vy
    x1 = x
    y1 = y

    # k2
    vx2 = vx + 0.5 * dt * dvx1
    vy2 = vy + 0.5 * dt * dvy1
    dvx2, dvy2 = derivatives(vx2, vy2)
    x2 = x + 0.5 * dt * vx1
    y2 = y + 0.5 * dt * vy1

    # k3
    vx3 = vx + 0.5 * dt * dvx2
    vy3 = vy + 0.5 * dt * dvy2
    dvx3, dvy3 = derivatives(vx3, vy3)
    x3 = x + 0.5 * dt * vx2
    y3 = y + 0.5 * dt * vy2

    # k4
    vx4 = vx + dt * dvx3
    vy4 = vy + dt * dvy3
    dvx4, dvy4 = derivatives(vx4, vy4)
    x4 = x + dt * vx3
    y4 = y + dt * vy3

    # Combine
    new_vx = vx + (dt / 6.0) * (dvx1 + 2*dvx2 + 2*dvx3 + dvx4)
    new_vy = vy + (dt / 6.0) * (dvy1 + 2*dvy2 + 2*dvy3 + dvy4)
    new_x = x + (dt / 6.0) * (vx1 + 2*vx2 + 2*vx3 + vx4)
    new_y = y + (dt / 6.0) * (vy1 + 2*vy2 + 2*vy3 + vy4)

    return [new_x, new_y, new_vx, new_vy]

def simulate(v0, angle_deg, Cd, area, mass, rho, dt):
    """
    Simulate projectile motion with quadratic drag.
    Returns (range_m, max_height_m, flight_time_s)
    """
    angle_rad = math.radians(angle_deg)
    vx0 = v0 * math.cos(angle_rad)
    vy0 = v0 * math.sin(angle_rad)

    k = 0.5 * Cd * rho * area / mass

    state = [0.0, 0.0, vx0, vy0]
    t = 0.0
    max_height = 0.0

    prev_state = state[:]
    prev_t = t

    # First step to ensure we have a point above ground
    while state[1] >= 0.0:
        # Update max height
        if state[1] > max_height:
            max_height = state[1]

        # Store previous state
        prev_state = state[:]
        prev_t = t

        # Advance
        state = rk4_step(state, dt, k)
        t += dt

        # Break if we have gone below ground
        if state[1] < 0.0:
            break

    # Linear interpolation to find more accurate impact time and range
    x0, y0 = prev_state[0], prev_state[1]
    x1, y1 = state[0], state[1]
    # y0 >= 0, y1 < 0
    if y1 == y0:
        # Avoid division by zero; fallback to last step
        impact_t = t
        impact_x = x1
    else:
        frac = -y0 / (y1 - y0)
        impact_t = prev_t + frac * dt
        impact_x = x0 + frac * (x1 - x0)

    return impact_x, max_height, impact_t

def main():
    parser = argparse.ArgumentParser(description="Projectile motion with quadratic air drag.")
    parser.add_argument("v0", type=float, help="Initial speed (m/s)")
    parser.add_argument("angle_deg", type=float, help="Launch angle (degrees)")
    parser.add_argument("Cd", type=float, help="Drag coefficient (dimensionless)")
    parser.add_argument("area", type=float, help="Cross-sectional area (m^2)")
    parser.add_argument("mass", type=float, help="Mass (kg)")
    parser.add_argument("--rho", type=float, default=1.225, help="Air density (kg/m^3)")
    parser.add_argument("--dt", type=float, default=0.001, help="Time step for RK4 (s)")
    args = parser.parse_args()

    rng, hmax, ftime = simulate(
        args.v0,
        args.angle_deg,
        args.Cd,
        args.area,
        args.mass,
        args.rho,
        args.dt
    )

    print(f"range_m {rng:.6f}")
    print(f"max_height_m {hmax:.6f}")
    print(f"flight_time_s {ftime:.6f}")

if __name__ == "__main__":
    main()
