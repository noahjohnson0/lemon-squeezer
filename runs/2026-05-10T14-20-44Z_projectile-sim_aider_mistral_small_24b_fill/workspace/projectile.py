import sys
import math

def rk4_step(f, y, t, dt):
    k1 = dt * f(y, t)
    k2 = dt * f(y + 0.5 * k1, t + 0.5 * dt)
    k3 = dt * f(y + 0.5 * k2, t + 0.5 * dt)
    k4 = dt * f(y + k3, t + dt)
    return y + (k1 + 2 * k2 + 2 * k3 + k4) / 6

def equations_of_motion(v, t, g, k):
    vx, vy = v
    speed = math.sqrt(vx**2 + vy**2)
    dvxdt = -k * speed * vx
    dvydt = -g - k * speed * vy
    return [dvxdt, dvydt]

def simulate_projectile(v0, angle_rad, Cd, area_m2, mass_kg, rho=1.225, dt=0.001):
    g = 9.81
    k = 0.5 * Cd * rho * area_m2 / mass_kg

    vx0 = v0 * math.cos(angle_rad)
    vy0 = v0 * math.sin(angle_rad)

    t = 0
    y = 0
    v = [vx0, vy0]
    x = 0
    y_max = 0

    while y >= 0:
        dvdt = equations_of_motion(v, t, g, k)
        v = rk4_step(lambda v: dvdt, v, t, dt)
        x += v[0] * dt
        y += v[1] * dt
        t += dt

        if y > y_max:
            y_max = y

    # Linear interpolation to find the exact impact time
    vy_prev = v[1]
    t_prev = t - dt
    y_prev = y - v[1] * dt

    impact_time = t_prev + (0 - y_prev) / ((v[1] + vy_prev) / 2)

    range_m = x
    max_height_m = y_max
    flight_time_s = impact_time

    print(f"range_m {range_m:.6f}")
    print(f"max_height_m {max_height_m:.6f}")
    print(f"flight_time_s {flight_time_s:.6f}")

if __name__ == '__main__':
    if len(sys.argv) < 5:
        print("Usage: projectile.py <v0> <angle_deg> <Cd> <area_m2> <mass_kg> [--rho RHO] [--dt DT]")
        sys.exit(1)

    v0 = float(sys.argv[1])
    angle_deg = float(sys.argv[2])
    Cd = float(sys.argv[3])
    area_m2 = float(sys.argv[4])
    mass_kg = float(sys.argv[5])

    rho = 1.225
    dt = 0.001

    i = 6
    while i < len(sys.argv):
        if sys.argv[i] == '--rho':
            rho = float(sys.argv[i + 1])
            i += 2
        elif sys.argv[i] == '--dt':
            dt = float(sys.argv[i + 1])
            i += 2
        else:
            print(f"Unknown argument: {sys.argv[i]}")
            sys.exit(1)

    angle_rad = math.radians(angle_deg)
    simulate_projectile(v0, angle_rad, Cd, area_m2, mass_kg, rho, dt)
