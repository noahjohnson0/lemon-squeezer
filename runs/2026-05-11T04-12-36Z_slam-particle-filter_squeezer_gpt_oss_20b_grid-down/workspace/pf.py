"""
Particle Filter implementation for 1‑D robot localisation.

This module defines a simple 1‑D particle filter suitable for a robot moving along a
corridor of limited length with a single range sensor providing the distance to
the rear wall at ``x=10``.

The implementation is deterministic – a seed of ``42`` is applied to the NumPy
random number generator when the module is imported.  This ensures that tests
can reproduce the same sequence of random numbers.

The :class:`ParticleFilter` exposes a minimal API required by the unit tests:

* :py:meth:`~ParticleFilter.__init__` – create the particles uniformly.
* :py:meth:`~ParticleFilter.predict` – apply odometry control with Gaussian
  motion noise.
* :py:meth:`~ParticleFilter.update` – compute weights via a Gaussian likelihood
  based on the forward‑facing sensor reading and resample the particle cloud.
* :py:meth:`~ParticleFilter.estimate` – return the mean of the particle
  distribution as a point estimate.

The filter is intentionally simple – it does not attempt to maintain a
smooth trajectory or incorporate sensor models beyond the range measurement.
"""

from __future__ import annotations

import numpy as np

# Deterministic behaviour – tests rely on reproducibility.
np.random.seed(42)


class ParticleFilter:
    """Simple 1‑D particle filter.

    Parameters
    ----------
    n_particles:
        Number of particles in the filter.
    corridor_length:
        Total length of the corridor.  The forward‑facing sensor measures the
        distance to the wall at ``x=corridor_length``.
    """

    def __init__(self, n_particles: int = 200, corridor_length: float = 10.0):
        self.n_particles = int(n_particles)
        self.corridor_length = float(corridor_length)
        # Initialise particles uniformly in [0, corridor_length]
        self.particles = np.random.uniform(
            low=0.0, high=self.corridor_length, size=self.n_particles
        )

    # ------------------------------------------------------------------
    # Prediction step
    # ------------------------------------------------------------------
    def predict(self, control: float, motion_noise_std: float = 0.1) -> None:
        """Move each particle according to control + Gaussian noise.

        Parameters
        ----------
        control:
            Intended displacement (in the same units as corridor length).
        motion_noise_std:
            Standard deviation of the Gaussian noise added to each step.
        """
        noise = np.random.normal(loc=0.0, scale=motion_noise_std, size=self.n_particles)
        self.particles += control + noise
        # Optional: we keep particles outside the corridor – they will simply
        # receive low weight in ``update``.

    # ------------------------------------------------------------------
    # Update (measurement) step
    # ------------------------------------------------------------------
    def update(self, observation: float, sensor_noise_std: float = 0.3) -> None:
        """Update particle weights from a distance‑to‑wall observation.

        Parameters
        ----------
        observation:
            Raw reading from the sensor – approximate distance from the
            current position to the wall at ``x=corridor_length``.
        sensor_noise_std:
            Standard deviation of the sensor measurement noise.
        """
        # Expected distance to wall for each particle: L - x
        expected = self.corridor_length - self.particles
        # Compute Gaussian likelihood
        diff = observation - expected
        # Using the formula: exp(-0.5 * (diff / sigma)^2)
        weights = np.exp(-0.5 * (diff / sensor_noise_std) ** 2)
        # Avoid zero total weight – if all particles are improbable, leave
        # weights uniform to prevent division by zero.
        weight_sum = weights.sum()
        if weight_sum == 0.0:
            weights = np.full(self.n_particles, 1.0 / self.n_particles)
        else:
            weights /= weight_sum
        # Resample particles with replacement according to weights
        indices = np.random.choice(self.n_particles, size=self.n_particles, replace=True, p=weights)
        self.particles = self.particles[indices]

    # ------------------------------------------------------------------
    # Estimation
    # ------------------------------------------------------------------
    def estimate(self) -> float:
        """Return the current mean position estimate.

        The estimate is simply the mean of the particle cloud.
        """
        return float(self.particles.mean())

# End of file
