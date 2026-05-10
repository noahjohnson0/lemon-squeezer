import numpy as np

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
    def __init__(self, initial_pos, initial_vel, process_var, measurement_var, dt=1.0):
        self.x = [initial_pos, initial_vel]
        self.P = [[process_var, 0], [0, measurement_var]]
        self.Q = [
            [(dt**3 / 3) * process_var, (dt**2 / 2) * process_var],
            [(dt**2 / 2) * process_var, dt * process_var]
        ]
        self.R = [[measurement_var]]
        self.F = [[1, dt], [0, 1]]
        self.H = [1, 0]
        self.dt = dt

    def predict(self):
        self.x = np.dot(self.F, self.x)
        self.P = np.dot(np.dot(self.F, self.P), self.F.T) + self.Q

    def update(self, z):
        y = np.array([z]) - np.dot(self.H, self.x)
        S = np.dot(np.dot(self.H, self.P), self.H.T) + self.R
        K = np.dot(np.dot(self.P, self.H.T), np.linalg.inv(S))
        self.x = self.x + np.dot(K, y)
        self.P = np.dot((np.eye(2) - np.dot(K, self.H)), self.P)

    def state(self):
        return (self.x[0], self.x[1])

    def covariance(self):
        return self.P
