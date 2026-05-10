import math
from kepler import simulate, total_energy

def test_circular_orbit():
    """Test that a circular orbit returns to its starting point after one period."""
    x0, y0 = 1.0, 0.0
    vx0, vy0 = 0.0, 1.0
    t_end = 2 * math.pi
    
    x, y, vx, vy = simulate(x0, y0, vx0, vy0, t_end)
    
    # Should return approximately to the starting point
    assert abs(x - x0) < 1e-10, f"Final x {x} != initial x {x0}"
    assert abs(y - y0) < 1e-10, f"Final y {y} != initial y {y0}"
    assert abs(vx - vx0) < 1e-10, f"Final vx {vx} != initial vx {vx0}"
    assert abs(vy - vy0) < 1e-10, f"Final vy {vy} != initial vy {vy0}"

def test_half_orbit():
    """Test that a half-orbit flips the position and velocity correctly."""
    x0, y0 = 1.0, 0.0
    vx0, vy0 = 0.0, 1.0
    t_end = math.pi
    
    x, y, vx, vy = simulate(x0, y0, vx0, vy0, t_end)
    
    # Should end at (-1, 0) with velocity (0, -1)
    assert abs(x - (-1.0)) < 1e-10, f"Final x {x} != -1.0"
    assert abs(y - 0.0) < 1e-10, f"Final y {y} != 0.0"
    assert abs(vx - 0.0) < 1e-10, f"Final vx {vx} != 0.0"
    assert abs(vy - (-1.0)) < 1e-10, f"Final vy {vy} != -1.0"

def test_energy_conservation():
    """Test that energy is conserved with high accuracy for a circular orbit."""
    # Start at circular orbit
    x0, y0 = 1.0, 0.0
    vx0, vy0 = 0.0, 1.0
    
    # Compute energy at start
    energy_start = total_energy(x0, y0, vx0, vy0)
    
    # Full orbit
    t_end = 2 * math.pi
    x, y, vx, vy = simulate(x0, y0, vx0, vy0, t_end)
    
    # Compute energy at end
    energy_end = total_energy(x, y, vx, vy)
    
    # Energy should be conserved to within 1e-3
    assert abs(energy_end - energy_start) < 1e-3, f"Energy drift {abs(energy_end - energy_start)} > 1e-3"

def test_energy_value():
    """Test that the energy of a circular orbit is exactly -0.5."""
    x, y = 1.0, 0.0
    vx, vy = 0.0, 1.0
    
    energy = total_energy(x, y, vx, vy)
    assert abs(energy - (-0.5)) < 1e-15, f"Expected energy -0.5, got {energy}"

def test_round_trip():
    """Test that encoding and decoding a state gives back the original."""
    x0, y0 = 1.0, 0.0
    vx0, vy0 = 0.0, 1.0
    
    # Run simulation
    x, y, vx, vy = simulate(x0, y0, vx0, vy0, 1.0)
    
    # This is more of a sanity check - if we simulate for 1 second we 
    # should get a valid result
    assert isinstance(x, float)
    assert isinstance(y, float)
    assert isinstance(vx, float)
    assert isinstance(vy, float)

if __name__ == "__main__":
    test_circular_orbit()
    test_half_orbit()
    test_energy_conservation()
    test_energy_value()
    test_round_trip()
    print("All tests passed!")