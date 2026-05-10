import math
import kepler

def test_circular_orbit():
    """Test that a circular orbit returns to its starting point"""
    # Start with circular orbit: x=1, y=0, vx=0, vy=1
    x0, y0, vx0, vy0 = 1.0, 0.0, 0.0, 1.0
    x, y, vx, vy = kepler.simulate(x0, y0, vx0, vy0, 2*math.pi, 1e-4)
    
    # Should return to nearly the same position after one orbit
    assert abs(x - x0) < 1e-3
    assert abs(y - y0) < 1e-3
    assert abs(vx - vx0) < 1e-3
    assert abs(vy - vy0) < 1e-3

def test_energy_conservation():
    """Test that energy is conserved"""
    x0, y0, vx0, vy0 = 1.0, 0.0, 0.0, 1.0
    x, y, vx, vy = kepler.simulate(x0, y0, vx0, vy0, 2*math.pi, 1e-4)
    
    energy_initial = kepler.total_energy(x0, y0, vx0, vy0)
    energy_final = kepler.total_energy(x, y, vx, vy)
    
    # Energy should be conserved (within numerical error)
    assert abs(energy_initial - energy_final) < 1e-6

def test_half_orbit():
    """Test half-orbit calculation"""
    x0, y0, vx0, vy0 = 1.0, 0.0, 0.0, 1.0
    x, y, vx, vy = kepler.simulate(x0, y0, vx0, vy0, math.pi, 1e-4)
    
    # After half orbit, should be at (-1, 0) with velocity (0, -1)
    assert abs(x - (-1.0)) < 1e-3
    assert abs(y) < 1e-3
    assert abs(vx) < 1e-3
    assert abs(vy - (-1.0)) < 1e-3

if __name__ == "__main__":
    test_circular_orbit()
    test_energy_conservation()
    test_half_orbit()
    print("All tests passed!")