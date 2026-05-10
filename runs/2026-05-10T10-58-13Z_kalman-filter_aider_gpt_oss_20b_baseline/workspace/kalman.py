import numpy as np

class Kalman1D:
    """Tracks position + velocity along one axis given noisy position measurements.

    State vector x = [position, velocity]^T.
    Transition: x_{k+1} = F x_k where F = [[1, dt], [0, 1]].
    Process noise covariance Q is provided at construction.
    Measurement model: z_k = H x_k + noise, with H = [1, 0] (we observe position only).

    Constructor:
      Kalman1D(initial_pos: float, initial_vel: float, process_var: float,
               measurement_var: float, dt: float = 1.0)

    Methods:
      predict() -> None              # advance time by dt, update mean + covariance
      update(z: float) -> None       # incorporate a position measurement
      state() -> tuple[float, float] # (position, velocity)
      covariance() -> list[list[float]]  # 2x2 estimate covariance P
    """

    def __init__(self, initial_pos: float, initial_vel: float,
                 process_var: float, measurement_var: float,
                 dt: float = 1.0):
        self.dt = dt
        # State transition matrix
        self.F = np.array([[1.0, self.dt],
                           [0.0, 1.0]])
        # Observation matrix
        self.H = np.array([[1.0, 0.0]])
        # Process noise covariance (acceleration noise model)
        self.Q = process_var * np.array([[self.dt ** 4 / 4.0, self.dt ** 3 / 2.0],
                                         [self.dt ** 3 / 2.0, self.dt ** 2]])
        # Measurement noise covariance
        self.R = np.array([[measurement_var]])
        # Initial state estimate
        self.x = np.array([[initial_pos],
                           [initial_vel]])
        # Initial covariance estimate (start with low uncertainty)
        self.P = np.zeros((2, 2))

    def predict(self) -> None:
        """Advance the state estimate by one time step."""
        # State prediction
        self.x = self.F @ self.x
        # Covariance prediction
        self.P = self.F @ self.P @ self.F.T + self.Q

    def update(self, z: float) -> None:
        """Incorporate a new position measurement."""
        z = np.array([[z]])
        # Innovation (measurement residual)
        y = z - self.H @ self.x
        # Innovation covariance
        S = self.H @ self.P @ self.H.T + self.R
        # Kalman gain
        K = self.P @ self.H.T @ np.linalg.inv(S)
        # State update
        self.x = self.x + K @ y
        # Covariance update
        I = np.eye(2)
        self.P = (I - K @ self.H) @ self.P

    def state(self) -> tuple[float, float]:
        """Return the current state estimate as (position, velocity)."""
        return float(self.x[0, 0]), float(self.x[1, 0])

    def covariance(self) -> list[list[float]]:
        """Return the current covariance matrix as a nested list."""
        return self.P.tolist()
