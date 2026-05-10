import math
from kepler import simulate, total_energy

# Test the specific rubric cases

print("Testing circular orbit case:")
result = simulate(1, 0, 0, 1, 2*math.pi, 1e-3)
print(f"simulate(1, 0, 0, 1, 2π) = {result}")
print(f"Expected ≈ (1, 0, 0, 1)")
print(f"Close enough: {abs(result[0] - 1) < 1e-10 and abs(result[1] - 0) < 1e-10 and abs(result[2] - 0) < 1e-10 and abs(result[3] - 1) < 1e-10}")

print("\nTesting half-orbit case:")
result = simulate(1, 0, 0, 1, math.pi)
print(f"simulate(1, 0, 0, 1, π) = {result}")
print(f"Expected ≈ (-1, 0, 0, -1)")
print(f"Close enough: {abs(result[0] - (-1)) < 1e-10 and abs(result[1] - 0) < 1e-10 and abs(result[2] - 0) < 1e-10 and abs(result[3] - (-1)) < 1e-10}")

print("\nTesting energy conservation:")
energy = total_energy(1, 0, 0, 1)
print(f"total_energy(1, 0, 0, 1) = {energy}")
print(f"Expected = -0.5: {abs(energy - (-0.5)) < 1e-15}")

# Test energy after full orbit
x, y, vx, vy = simulate(1, 0, 0, 1, 2*math.pi, 1e-3)
energy_after = total_energy(x, y, vx, vy)
print(f"Energy after full orbit: {energy_after}")
print(f"Energy drift: {abs(energy_after - energy)}")
print(f"Drift < 1e-3: {abs(energy_after - energy) < 1e-3}")