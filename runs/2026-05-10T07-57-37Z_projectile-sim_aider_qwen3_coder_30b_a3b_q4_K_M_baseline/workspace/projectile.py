#!/usr/bin/env python3

import sys
import math

def main():
    if len(sys.argv) < 6:
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
        if sys.argv[i] == "--rho":
            rho = float(sys.argv[i+1])
            i += 2
        elif sys.argv[i] == "--dt":
            dt = float(sys.argv[i+1])
            i += 2
        else:
            i += 1
    
    # Constants
    g = 9.81
    k = 0.5 * Cd * rho * area_m2 / mass_kg
    
    # Initial conditions
    angle_rad = math.radians(angle_deg)
    vx = v0 * math.cos(angle_rad)
    vy = v0 * math.sin(angle_rad)
    x = 0.0
    y = 0.0
    
    # Store previous state for interpolation
    x_prev = 0.0
    y_prev = 0.0
    vx_prev = vx
    vy_prev = vy
    
    # Track max height
    max_height = 0.0
    
    # RK4 integration
    while True:
        # Store current state
        x_prev = x
        y_prev = y
        vx_prev = vx
        vy_prev = vy
        
        # Calculate k1
        v = math.sqrt(vx**2 + vy**2)
        k1_vx = -k * v * vx
        k1_vy = -g - k * v * vy
        k1_x = vx
        k1_y = vy
        
        # Calculate k2
        vx2 = vx + k1_vx * dt / 2
        vy2 = vy + k1_vy * dt / 2
        x2 = x + k1_x * dt / 2
        y2 = y + k1_y * dt / 2
        v2 = math.sqrt(vx2**2 + vy2**2)
        k2_vx = -k * v2 * vx2
        k2_vy = -g - k * v2 * vy2
        k2_x = vx2
        k2_y = vy2
        
        # Calculate k3
        vx3 = vx + k2_vx * dt / 2
        vy3 = vy + k2_vy * dt / 2
        x3 = x + k2_x * dt / 2
        y3 = y + k2_y * dt / 2
        v3 = math.sqrt(vx3**2 + vy3**2)
        k3_vx = -k * v3 * vx3
        k3_vy = -g - k * v3 * vy3
        k3_x = vx3
        k3_y = vy3
        
        # Calculate k4
        vx4 = vx + k3_vx * dt
        vy4 = vy + k3_vy * dt
        x4 = x + k3_x * dt
        y4 = y + k3_y * dt
        v4 = math.sqrt(vx4**2 + vy4**2)
        k4_vx = -k * v4 * vx4
        k4_vy = -g - k * v4 * vy4
        k4_x = vx4
        k4_y = vy4
        
        # Update state
        vx = vx + (k1_vx + 2*k2_vx + 2*k3_vx + k4_vx) * dt / 6
        vy = vy + (k1_vy + 2*k2_vy + 2*k3_vy + k4_vy) * dt / 6
        x = x + (k1_x + 2*k2_x + 2*k3_x + k4_x) * dt / 6
        y = y + (k1_y + 2*k2_y + 2*k3_y + k4_y) * dt / 6
        
        # Track max height
        if y > max_height:
            max_height = y
        
        # Check if projectile has hit the ground
        if y < 0:
            # Linear interpolation to find exact impact time
            t_impact = (y_prev / (y - y_prev)) * dt
            # Adjust final position to ground level
            x = x_prev - (y_prev / (y - y_prev)) * (x - x_prev)
            break
    
    # Calculate range and flight time
    range_m = x
    flight_time_s = (x_prev / (x - x_prev)) * dt + (x - x_prev) / (x - x_prev) * dt
    
    # Print results
    print(f"range_m {range_m:.6f}")
    print(f"max_height_m {max_height:.6f}")
    print(f"flight_time_s {flight_time_s:.6f}")

if __name__ == "__main__":
    main()
