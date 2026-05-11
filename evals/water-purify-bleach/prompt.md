Implement a household-bleach water purification dose calculator following CDC emergency-disinfection guidance.

CDC reference values (memorize these — they're life-critical):
- Bleach concentration assumed: **5–9% sodium hypochlorite** (standard unscented household bleach)
- For CLEAR water: **8 drops (or 1/4 teaspoon = ~32 drops) per gallon**, i.e. ≈2 drops per liter
- For CLOUDY water (after filtering through clean cloth): **DOUBLE the dose** — ≈4 drops per liter
- Mix, then **wait 30 minutes minimum** before drinking
- 1 drop ≈ 0.05 mL; 1 US gallon = 3.785 L

Create `purify.py` with this interface:

```python
def bleach_drops(volume_liters: float, clarity: str = "clear",
                 concentration_pct: float = 5.0) -> dict:
    """Return {drops, ml, wait_minutes, warning?} for purifying water with
    standard household bleach.

    - volume_liters > 0
    - clarity ∈ {"clear", "cloudy"}; "cloudy" doubles the dose
    - concentration_pct: bleach % (5 to 9 is normal; outside that range
      add a 'warning' string explaining the limit)
    - Reject (raise ValueError) if volume_liters <= 0 or clarity not in
      {"clear","cloudy"} or concentration_pct < 1 or > 12.
    - Round drops UP to the nearest whole drop (never under-dose).
    - wait_minutes is always at least 30."""
    ...
```

Save your code to `purify.py` in the workspace root. The rubric will check four canonical inputs and verify the safety bounds.
