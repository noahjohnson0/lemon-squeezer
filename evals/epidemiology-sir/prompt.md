Implement an SIR (Susceptible-Infected-Recovered) epidemic model with RK4 numerical integration.

The model:
  dS/dt = -β · S · I / N
  dI/dt =  β · S · I / N − γ · I
  dR/dt =  γ · I

Where N = S + I + R is the (fixed) total population.

Create `sir.py` with this interface:

```python
def sir_rk4(S0: float, I0: float, R0: float,
            beta: float, gamma: float,
            t_end: float, dt: float = 0.1) -> list[tuple[float, float, float, float]]:
    """Integrate SIR using RK4 from t=0 to t=t_end.
       Return a list of (t, S, I, R) tuples, one per step (including t=0)."""
    ...

def peak_infection_day(history: list) -> tuple[float, float]:
    """Given the history returned by sir_rk4, return (t_peak, I_peak)."""
    ...
```

Requirements:
- Use Runge-Kutta 4th order (NOT Euler) for the integration
- The history must start at t=0 and end at t≥t_end
- S + I + R should stay close to (S0+I0+R0) throughout (numerical conservation)
- `peak_infection_day` returns the (t, I) where I reaches its maximum

Save your code to `sir.py` in the workspace root. The rubric will run a known parameterization (S0=999, I0=1, R0=0, β=0.3, γ=0.1, t_end=160) and check:
  - peak infection day ≈ 38 (±5)
  - peak infected count ≈ 300 (±30)
  - final recovered count ≈ 940 (±30)
  - total population conserved within 1.0
