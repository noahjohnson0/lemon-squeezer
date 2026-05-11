Implement inverse kinematics for a 2-link planar robot arm.

The arm has:
- Base at origin (0, 0)
- Link 1 of length L1 = 1.0 m, rotates at the base by angle θ₁ (radians, CCW from +x axis)
- Link 2 of length L2 = 1.0 m, attached at the end of link 1, rotates by angle θ₂ relative to link 1's direction

Forward kinematics:
  x = L1·cos(θ₁) + L2·cos(θ₁+θ₂)
  y = L1·sin(θ₁) + L2·sin(θ₁+θ₂)

Create `ik.py` exposing:

```python
L1 = 1.0
L2 = 1.0

def inverse_kinematics(x: float, y: float, elbow: str = "up") -> tuple[float, float]:
    """Return (theta1, theta2) in radians for the given end-effector target.
       elbow='up' or 'down' selects the configuration.
       Raise ValueError if the target is unreachable."""
    ...

def forward_kinematics(theta1: float, theta2: float) -> tuple[float, float]:
    """Return (x, y) for the given joint angles. Useful for self-check."""
    ...
```

Save your code to `ik.py` in the workspace root. The rubric will:
- Verify `forward_kinematics(*inverse_kinematics(x, y))` returns approximately (x, y) for 5 reachable targets
- Verify ValueError raised when distance from origin > L1+L2
- Verify both elbow-up and elbow-down give valid (different) solutions for one target
