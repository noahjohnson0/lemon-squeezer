"""
2-link planar arm kinematics.

This module defines the forward and inverse kinematics for a planar 2‑link arm
with a base at the origin. The link lengths are parameters `L1` and `L2`.

The inverse kinematics solve for the joint angles 
`theta1` (base) and `theta2` (relative to link 1). Two solutions exist for a
given target: the *elbow‑up* and *elbow‑down* configurations.

Unreachable targets raise a :class:`ValueError`.
"""

from __future__ import annotations

import math

# Link lengths (meters)
L1: float = 1.0
L2: float = 1.0


def forward_kinematics(theta1: float, theta2: float) -> tuple[float, float]:
    """Return the end‑effector position (x, y) for the given joint angles.

    Parameters
    ----------
    theta1
        Base angle in radians (counter‑clockwise from +x).
    theta2
        Secondary joint angle in radians, measured relative to link 1.

    Returns
    -------
    tuple[float, float]
        (x, y) position in 2‑D space.
    """
    x = L1 * math.cos(theta1) + L2 * math.cos(theta1 + theta2)
    y = L1 * math.sin(theta1) + L2 * math.sin(theta1 + theta2)
    return x, y


def _solve_for_theta2(x: float, y: float) -> float:
    """Helper to compute the cosine of theta2 for a target.

    Raises
    ------
    ValueError
        If the target is outside the robot reach.
    """
    r_sq = x * x + y * y
    denom = 2 * L1 * L2
    # Cosine of theta2 via law of cosines
    cos_t2 = (r_sq - L1 * L1 - L2 * L2) / denom
    # Numerical errors may push cos_t2 slightly outside [-1, 1]
    if cos_t2 > 1 and cos_t2 <= 1 + 1e-9:
        cos_t2 = 1.0
    if cos_t2 < -1 and cos_t2 >= -1 - 1e-9:
        cos_t2 = -1.0
    if not -1.0 <= cos_t2 <= 1.0:
        raise ValueError(f"Target ({x:.3f}, {y:.3f}) is unreachable.")
    return math.acos(cos_t2)


def inverse_kinematics(x: float, y: float, elbow: str = "up") -> tuple[float, float]:
    """Return the joint angles that place the end‑effector at (x, y).

    Parameters
    ----------
    x, y
        Desired end‑effector coordinates.
    elbow
        Which elbow configuration to return: ``"up"`` or ``"down"``.

    Returns
    -------
    tuple[float, float]
        (theta1, theta2) in radians.

    Raises
    ------
    ValueError
        If the target is unreachable.
    ValueError
        If an invalid elbow option is supplied.
    """
    if elbow not in ("up", "down"):
        raise ValueError("elbow must be 'up' or 'down'")

    # Get the principal value of theta2
    phi = _solve_for_theta2(x, y)
    # Switch sign for elbow down
    if elbow == "down":
        phi = -phi

    # Compute theta1 using atan2 formulation
    # k1 = L1 + L2 * cos(theta2), k2 = L2 * sin(theta2)
    k1 = L1 + L2 * math.cos(phi)
    k2 = L2 * math.sin(phi)
    theta1 = math.atan2(y, x) - math.atan2(k2, k1)

    return theta1, phi


# Self‑check example (commented out to avoid side effects on import)
# if __name__ == "__main__":
#     import random
#     for _ in range(5):
#         # Random reachable target
#         theta1 = random.uniform(-math.pi, math.pi)
#         theta2 = random.uniform(-math.pi, math.pi)
#         x, y = forward_kinematics(theta1, theta2)
#         t1, t2 = inverse_kinematics(x, y, elbow="up")
#         print(f"original=({theta1:.3f},{theta2:.3f}) recovered=({t1:.3f},{t2:.3f})")

EOF