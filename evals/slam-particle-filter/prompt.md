Implement a 1D particle filter for robot localization.

Setting: a robot moves along a 10-meter corridor. Each step, the robot is told how far it tried to move (odometry, noisy) and gets a noisy distance-to-wall reading from a forward-facing sensor. The corridor has a wall at x = 10 m. The robot estimates its position using a particle filter.

Create `pf.py` with this interface:

```python
class ParticleFilter:
    def __init__(self, n_particles: int = 200, corridor_length: float = 10.0):
        # Initialize n_particles uniformly in [0, corridor_length]
        ...
    def predict(self, control: float, motion_noise_std: float = 0.1) -> None:
        # Move each particle by control + Gaussian noise
        ...
    def update(self, observation: float, sensor_noise_std: float = 0.3) -> None:
        # Weight each particle by Gaussian likelihood of (corridor_length - particle_x) ≈ observation
        # Then resample with replacement proportional to weights
        ...
    def estimate(self) -> float:
        # Return current mean position estimate
        ...
```

Implementation notes:
- Use numpy if available; pure-python lists are also fine
- Particles can move outside [0, corridor_length] during prediction - that's OK; they'll get low weight on update
- Weights must be normalized before resampling
- Use deterministic randomness: seed numpy/random at module load with seed=42 OR provide a way for the test to seed it

Save your code to `pf.py` in the workspace root. The rubric will simulate a robot moving from x=2.0 in steps of 0.5 m and verify the filter converges to truth within 0.7 m after 30 update cycles.
