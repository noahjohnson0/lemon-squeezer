import argparse
import math

def derivatives(state, t, k, g):
    x, y, vx, vy = state
    speed = math.sqrt(vx**2 + vy**2)
    dvx_dt = -k * speed * vx
    dvy_dt = -g - k * speed * vy
    return [vx, vy, dvx_dt, dvy_dt]

def rk4_step(state, t, dt, k, g):
    k1 = derivatives(state, t, k, g)
    k2 = derivatives([state[i] + k1[i] * dt/2 for i in range(4)], t + dt/2, k, g)
    k3 = derivatives([state[i] + k2[i] * dt/2 for i in range(4)], t + dt/2, k, g)
    k4 = derivatives([state[i] + k3[i] * dt for i in range(4)], t + dt, k, g)
    new_state = [
        state[0] + (k1[0] + 2*k2[0] + 2*k3[0] + k4[0]) * dt / 6,
        state[1] + (k1[1] + 2*k2[1] + 2*k3[1] + k4[1]) * dt / 6,
        state[2] + (k1[2] + 2*k2[2] + 2*k3[2] + k4[2]) * dt / 6,
        state[3] + (k1[3] + 2*k2[3] + 2*k3[3] + k4[3]) * dt / 6,
    ]
    return new_state, t + dt

def main():
    parser = argparse.ArgumentParser(description='Simulate projectile motion with quadratic air drag.')
    parser.add_argument('v0', type=float, help='Initial velocity in m/s')
    parser.add_argument('angle_deg', type=float, help='Launch angle in degrees')
    parser.add_argument('Cd', type=float, help='Drag coefficient')
    parser.add_argument('area', type=float, help='Cross-sectional area in m²')
    parser.add_argument('mass', type=float, help='Mass in kg')
    parser.add_argument('--rho', type=float, default=1.225, help='Air density (default: 1.225 kg/m³)')
    parser.add_argument('--dt', type=float, default=0.001, help='Time step (default: 0.001 s)')
    args = parser.parse_args()

    theta = math.radians(args.angle_deg)
    v0x = args.v0 * math.cos(theta)
    v0y = args.v0 * math.sin(theta)

    k = 0.5 * args.Cd * args.rho * args.area / args.mass
    g = 9.81

    # Initial state: [x, y, vx, vy]
    state = [0.0, 0.0, v0x, v0y]
    t = 0.0
    prev_state = [0.0, 0.0, v0x, v0y]
    prev_t = 0.0

    max_height = 0.0
    max_height_x = 0.0

    while True:
        # Perform RK4 step
        state, t = rk4_step(state, t, args.dt, k, g)
        # Check if y is negative
        if state[1] < 0:
            # Interpolate between previous state and current state
            impact_time = prev_t + (0 - prev_state[1]) * (t - prev_t) / (state[1] - prev_state[1])
            # Calculate range
            range_m = prev_state[0] + (state[0] - prev_state[0]) * (impact_time - prev_t) / (t - prev_t)
            break
        else:
            # Update max height
            if state[1] > max_height:
                max_height = state[1]
                max_height_x = state[0]
            # Save current state as previous for next iteration
            prev_state = list(state)
            prev_t = t

    print(f"range_m {range_m:.6f}")
    print(f"max_height_m {max_height:.6f}")
    print(f"flight_time_s {impact_time:.6f}")

if __name__ == '__main__':
    main()
