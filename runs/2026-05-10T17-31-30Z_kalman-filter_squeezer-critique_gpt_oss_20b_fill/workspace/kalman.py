"""Kalman1D: Constant‑velocity 1‑D Kalman filter.

The implementation follows the classic linear Kalman filter equations
with a 2‑dimensional state vector ``x = [position, velocity]^T``.

The class is intentionally lightweight – it only depends on ``numpy``
and performs the basic linear algebra needed for prediction and update.
"""

from __future__ import annotations

import numpy as np


class Kalman1D:
    """Tracks position + velocity along one axis given noisy position measurements.

    State vector ``x`` = ``[position, velocity]^T``.
    Transition: ``x_{k+1} = F x_k`` where ``F`` = ``[[1, dt], [0, 1]]``.
    Process noise covariance ``Q`` is a scalar ``process_var`` passed to the
    constructor and expanded to a diagonal ``2x2`` matrix – this is
    sufficient for many constant‑velocity tracking scenarios.
    Measurement model: ``z_k = H x_k + noise`` where ``H`` = ``[1, 0]``
    (we observe position only).

    Parameters
    ----------
    initial_pos: float
        Initial estimated position.
    initial_vel: float
        Initial estimated velocity.
    process_var: float
        Variance of the process noise applied to both state variables.
        Internally expressed as ``Q = process_var*np.eye(2)``.
    measurement_var: float
        Variance of the measurement noise (position only).
    dt: float, optional, default=1.0
        Sampling time.  Default to 1.0 seconds.
    """

    def __init__(self, initial_pos: float, initial_vel: float,
                 process_var: float, measurement_var: float,
                 dt: float = 1.0) -> None:
        self.dt = float(dt)
        self.F = np.array([[1.0, self.dt],
                           [0.0, 1.0]], dtype=float)
        self.H = np.array([[1.0, 0.0]], dtype=float)  # row vector
        self.R = float(measurement_var)
        self.Q = process_var * np.eye(2, dtype=float)
        self.x = np.array([[float(initial_pos)],
                           [float(initial_vel)]], dtype=float)
        # Initial covariance – start with small uncertainty
        self.P = np.eye(2, dtype=float)

    def predict(self) -> None:
        """Advance the filter state one time step (prediction)."""
        # state prediction
        self.x = self.F @ self.x
        # covariance prediction
        self.P = self.F @ self.P @ self.F.T + self.Q

    def update(self, z: float) -> None:
        """Incorporate a noisy position measurement ``z``.

        Parameters
        ----------
        z: float
            Noisy measurement of the position.
        """
        z = float(z)
        # Innovation
        y = z - (self.H @ self.x).item()
        # Innovation covariance
        S = (self.H @ self.P @ self.H.T).item() + self.R
        # Kalman gain
        K = (self.P @ self.H.T) / S  # shape (2,1)
        # State update
        self.x = self.x + K * y
        # Covariance update – Joseph form for numerical stability
        I = np.eye(2, dtype=float)
        self.P = (I - K @ self.H) @ self.P

    def state(self) -> tuple[float, float]:
        """Return the current state estimate ``(position, velocity)``."""
        return float(self.x[0, 0]), float(self.x[1, 0])

    def covariance(self) -> list[list[float]]:
        """Return a plain Python list representation of the 2x2 covariance matrix."""
        return [list(row) for row in self.P.tolist()]

# If script is executed directly, perform a very light test
if __name__ == "__main__":
    import random

    kf = Kalman1D(0.0, 0.0, process_var=1e-5, measurement_var=1.0)
    true_pos = 0.0
    true_vel = 1.0
    for step in range(5):
        true_pos += true_vel
        meas = true_pos + random.gauss(0, 1.0)
        kf.predict()
        kf.update(meas)
        pos, vel = kf.state()
        print(step, "true", true_pos, "meas", meas, "est", pos, vel)

"""EOF"""
