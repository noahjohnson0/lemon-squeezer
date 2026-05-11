"""
2‑link planar robot arm inverse and forward kinematics.

The arm has:
- Base at the origin (0, 0)
- Link 1 of length L1 = 1.0 m, rotates at the base by angle θ₁ (radians, CCW from +x axis)
- Link 2 of length L2 = 1.0 m, attached at the end of link 1, rotates by angle θ₂ relative to link 1's direction

Forward kinematics:
    x = L1·cos(θ₁) + L2·cos(θ₁+θ₂)
    y = L1·sin(θ₁) + L2·sin(θ₁+θ₂)

Inverse kinematics:
    Uses the law of cosines to compute θ₂ and then θ₁.
    The `elbow` argument selects the elbow‑up or elbow‑down configuration.
"""

import math
from typing import Tuple

# Link lengths
L1: float = 1.0
L2: float = 1.0

def _clamp(value: float, min_value: float, max_value: float) -> float:
    """Clamp a value to the inclusive range [min_value, max_value]."""
    return max(min_value, min(max_value, value))

def inverse_kinematics(x: float, y: float, elbow: str = "up") -> Tuple[float, float]:
    """
    Return (theta1, theta2) in radians for the given end‑effector target.

    Parameters
    ----------
    x, y : float
        Desired end‑effector position in the plane.
    elbow : str, optional
        Either "up" or "down" to select the elbow configuration.
        Defaults to "up".

    Returns
    -------
    tuple[float, float]
        (theta1, theta2) in radians.

    Raises
    ------
    ValueError
        If the target is unreachable.
    """
    if elbow not in ("up", "down"):
        raise ValueError("elbow must be 'up' or 'down'")

    # Distance from base to target
    r = math.hypot(x, y)

    # Check reachability
    if r > (L1 + L2) + 1e-9 or r < abs(L1 - L2) - 1e-9:
        raise ValueError(f"Target ({x:.3f}, {y:.3f}) is unreachable (distance {r:.3f})")

    # Law of cosines for theta2
    cos_theta2 = (x**2 + y**2 - L1**2 - L2**2) / (2 * L1 * L2)
    cos_theta2 = _clamp(cos_theta2, -1.0, 1.0)  # Numerical safety
    theta2 = math.acos(cos_theta2)

    # Choose elbow configuration
    if elbow == "down":
        theta2 = -theta2

    # Compute theta1
    # Using atan2 to handle all quadrants
    k1 = L1 + L2 * math.cos(theta2)
    k2 = L2 * math.sin(theta2)
    theta1 = math.atan2(y, x) - math.atan2(k2, k1)

    # Normalize angles to [-pi, pi]
    theta1 = (theta1 + math.pi) % (2 * math.pi) - math.pi
    theta2 = (theta2 + math.pi) % (2 * math.pi) - math.pi

    return theta1, theta2

def forward_kinematics(theta1: float, theta2: float) -> Tuple[float, float]:
    """
    Return (x, y) for the given joint angles.

    Parameters
    ----------
    theta1, theta2 : float
        Joint angles in radians.

    Returns
    -------
    tuple[float, float]
        (x, y) position of the end‑effector.
    """
    x = L1 * math.cos(theta1) + L2 * math.cos(theta1 + theta2)
    y = L1 * math.sin(theta1) + L2 * math.sin(theta1 + theta2)
    return x, y
