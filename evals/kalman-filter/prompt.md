Write `kalman.py` exporting a 1D constant-velocity Kalman filter:

```python
class Kalman1D:
    """Tracks position + velocity along one axis given noisy position measurements.

    State vector x = [position, velocity]^T.
    Transition: x_{k+1} = F x_k where F = [[1, dt], [0, 1]].
    Process noise covariance Q is provided at construction.
    Measurement model: z_k = H x_k + noise, with H = [1, 0] (we observe position only).

    Constructor:
      Kalman1D(initial_pos: float, initial_vel: float, process_var: float, measurement_var: float, dt: float = 1.0)

    Methods:
      predict() -> None              # advance time by dt, update mean + covariance
      update(z: float) -> None       # incorporate a position measurement
      state() -> tuple[float, float] # (position, velocity)
      covariance() -> list[list[float]]  # 2x2 estimate covariance P
    """
```

Pure-python or numpy. No filterpy / pykalman.

Sanity test the rubric will run: with constant velocity 1.0 m/s and noisy measurements around the true trajectory, the filter's velocity estimate must converge to ~1.0 ± 0.2 within 50 steps.

Create only `kalman.py`. Don't run it.
