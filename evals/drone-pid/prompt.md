Implement a PID controller class for drone altitude hold.

Create a single file `pid.py` with this exact interface:

```python
class PID:
    def __init__(self, kp: float, ki: float, kd: float, setpoint: float = 0.0):
        ...
    def update(self, measurement: float, dt: float) -> float:
        """Compute control output given the current measurement and timestep."""
        ...
    def reset(self) -> None:
        """Zero internal integral and previous-error state."""
        ...
    def set_setpoint(self, setpoint: float) -> None: ...
    def set_gains(self, kp: float, ki: float, kd: float) -> None: ...
```

Requirements:
- Classical PID: output = Kp·e + Ki·∫e dt + Kd·(de/dt), where e = setpoint − measurement
- `update` must handle the FIRST call gracefully (no prior error to derive from - return Kp·e + Ki·e·dt, derivative term 0)
- Anti-windup: clamp the integral term to ±100 to prevent runaway
- `reset()` must zero both the integral accumulator and the last-error memory

When the agent finishes, write `pid.py` to the workspace root. The rubric will instantiate `PID(kp=2.0, ki=0.5, kd=0.8, setpoint=10.0)` and step it through a simulated first-order plant for 200 steps of dt=0.05, then verify settling behavior.
