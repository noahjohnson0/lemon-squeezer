import sys
import math

def rk4_step(f, t, y, h):
    k1 = h * f(t, y)
    k2 = h * f(t + 0.5*h, y + 0.5*k1)
    k3 = h * f(t + 0.5*h, y + 0.5*k2)
    k4 = h * f(t + h, y + k3)
    return y + (k1 + 2*k2 + 2*k3 + k4) / 6

def projectile_motion(v0, angle_deg, Cd, area, mass, rho=1.225, dt=0.001):
    g = 9.81
    theta = math.radians(angle_deg)
    vx0 = v0 * math.cos(theta)
    vy0 = v0 * math.sin(theta)

    k = 0.5 * Cd * rho * area / mass

    def dvdt(t, y):
        vx, vy = y
        v = math.sqrt(vx**2 + vy**2)
        return [ -k * v * vx, -g - k * v * vy ]

    t = 0
    y = [vx0, vy0]
    x = 0
    max_height = 0

    while y[1] >= 0:
        k1 = dvdt(t, y)
        k2 = dvdt(t + dt/2, [y[i] + dt/2 * k1[i] for i in range(2)])
        k3 = dvdt(t + dt/2, [y[i] + dt/2 * k2[i] for i in range(2)])
        k4 = dvdt(t + dt, [y[i] + dt * k3[i] for i in range(2)])

        y = [y[i] + dt/6 * (k1[i] + 2*k2[i] + 2*k3[i] + k4[i]) for i in range(2)]
        x += vx0 * dt
        t += dt

        if y[1] > max_height:
            max_height = y[1]

    # Linear interpolation to find impact time precisely
    t_impact = t - (y[1] / (y[1] - (y[1] + k4[1]*dt)))

    return x, max_height, t_impact

def main():
    if len(sys.argv) < 6:
        print("Usage: projectile.py <v0> <angle_deg> <Cd> <area_m2> <mass_kg> [--rho RHO] [--dt DT]")
        sys.exit(1)

    v0 = float(sys.argv[1])
    angle_deg = float(sys.argv[2])
    Cd = float(sys.argv[3])
    area = float(sys.argv[4])
    mass = float(sys.argv[5])

    rho = 1.225
    dt = 0.001

    if len(sys.argv) > 6:
        for i in range(6, len(sys.argv), 2):
            if sys.argv[i] == "--rho":
                rho = float(sys.argv[i+1])
            elif sys.argv[i] == "--dt":
                dt = float(sys.argv[i+1])

    range_m, max_height_m, flight_time_s = projectile_motion(v0, angle_deg, Cd, area, mass, rho, dt)

    print(f"range_m {range_m:.6f}")
    print(f"max_height_m {max_height_m:.6f}")
    print(f"flight_time_s {flight_time_s:.6f}")

if __name__ == "__main__":
    main()
