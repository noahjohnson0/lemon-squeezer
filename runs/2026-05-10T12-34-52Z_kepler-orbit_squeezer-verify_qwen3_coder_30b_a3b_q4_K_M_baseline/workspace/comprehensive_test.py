import math
from kepler import simulate, total_energy

def test_energy_preservation_property():
    """Property: Energy should be conserved for any circular orbit"""
    # Test multiple circular orbits with different radii
    radii = [0.5, 1.0, 2.0, 5.0]
    
    for r in radii:
        # Set up circular orbit: position (r, 0), velocity (0, sqrt(1/r^3))
        x0, y0 = r, 0
        vx0, vy0 = 0, math.sqrt(1/(r**3))
        
        # Calculate initial energy
        energy_initial = total_energy(x0, y0, vx0, vy0)
        
        # Simulate full orbit
        t_end = 2 * math.pi * math.sqrt(r**3)
        x, y, vx, vy = simulate(x0, y0, vx0, vy0, t_end)
        
        # Calculate final energy
        energy_final = total_energy(x, y, vx, vy)
        
        # Energy should be conserved
        print(f"Radius {r}: Initial = {energy_initial}, Final = {energy_final}, Drift = {abs(energy_final - energy_initial)}")
        assert abs(energy_final - energy_initial) < 1e-3, f"Energy not conserved for radius {r}"

def test_consistency_property():
    """Property: Different time steps should give similar results (within tolerance)"""
    x0, y0 = 1.0, 0.0
    vx0, vy0 = 0.0, 1.0
    
    # Run with different time steps
    dt_values = [1e-2, 1e-3, 1e-4]
    results = []
    
    for dt in dt_values:
        x, y, vx, vy = simulate(x0, y0, vx0, vy0, 2*math.pi, dt)
        results.append((x, y, vx, vy))
    
    # All results should be close to each other (within some tolerance)
    # For a circular orbit, we expect the system to return to nearly the starting point
    expected = (1.0, 0.0, 0.0, 1.0)
    
    for i, result in enumerate(results):
        print(f"dt={dt_values[i]}: result={result}")
        # Check if each coordinate is close to expected (not exact due to numerical errors)
        for j in range(4):
            assert abs(result[j] - expected[j]) < 0.01, f"Result {i} not close to expected with dt={dt_values[i]}"

def test_edge_cases():
    """Test edge cases"""
    # Very small time step
    result = simulate(1, 0, 0, 1, 0.001, 1e-6)
    assert isinstance(result, tuple)
    assert len(result) == 4
    
    # Long integration time
    result = simulate(1, 0, 0, 1, 100, 1e-3)
    assert isinstance(result, tuple)
    assert len(result) == 4

if __name__ == "__main__":
    test_energy_preservation_property()
    print("✓ Energy preservation property test passed")
    
    test_consistency_property()
    print("✓ Consistency property test passed")
    
    test_edge_cases()
    print("✓ Edge cases test passed")
    
    print("All comprehensive tests passed!")