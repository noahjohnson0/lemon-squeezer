# Keplerian Orbit Simulation

This package implements functions for simulating Keplerian orbital mechanics with a central mass at the origin (GM=1.0).

## Functions

### `simulate(x, y, vx, vy, t, dt=1e-3)`
Integrates a 2D Kepler problem using 4th-order Runge-Kutta integration.

**Parameters:**
- `x, y`: Initial position coordinates
- `vx, vy`: Initial velocity components  
- `t`: Total simulation time
- `dt`: Time step (default: 1e-3)

**Returns:**
- Tuple of final (x, y, vx, vy) coordinates

### `total_energy(x, y, vx, vy)`
Calculates the total mechanical energy of the system.

**Parameters:**
- `x, y`: Position coordinates
- `vx, vy`: Velocity components

**Returns:**
- Total specific orbital energy (kinetic + potential)

## Usage Example

```python
import kepler
import math

# Circular orbit: x=1, y=0, vx=0, vy=1
x, y, vx, vy = kepler.simulate(1.0, 0.0, 0.0, 1.0, 2*math.pi, 1e-4)

# Calculate energy
energy = kepler.total_energy(x, y, vx, vy)
print(f"Final energy: {energy}")
```

## Key Features

- **Accurate Physics**: Implements proper orbital mechanics with GM=1.0
- **Numerical Stability**: Uses 4th-order Runge-Kutta for accurate integration
- **Energy Conservation**: Maintains energy within acceptable bounds (drift < 1e-6 for circular orbits)
- **Proper Testing**: Verified with circular orbits, half-orbits, and energy conservation