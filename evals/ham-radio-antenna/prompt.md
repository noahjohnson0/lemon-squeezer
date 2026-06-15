Implement antenna math for amateur (ham) radio operators.

Speed of light: c = 299,792,458 m/s. For practical antenna work the conversion 300 / f(MHz) = wavelength in meters is used.

A half-wave **dipole** in free space has each leg ≈ a quarter-wavelength. Practical correction for wire insulation + end effects: multiply the free-space length by **0.95** (the "velocity factor for thin wire") for the actual cut length.

A **quarter-wave vertical** monopole over a ground plane has length ≈ one quarter wavelength, also multiplied by 0.95.

Create `antenna.py` exposing:

```python
def wavelength_m(freq_mhz: float) -> float:
    """Free-space wavelength in meters."""
    ...

def dipole_total_length(freq_mhz: float) -> float:
    """Practical total length (meters) of a half-wave dipole (both legs together).
       Returns wavelength_m / 2 * 0.95."""
    ...

def dipole_leg_length(freq_mhz: float) -> float:
    """One leg of the half-wave dipole, in meters."""
    ...

def quarter_wave_vertical_m(freq_mhz: float) -> float:
    """Length of a quarter-wave vertical, in meters (with 0.95 correction)."""
    ...

def band_for_frequency(freq_mhz: float) -> str:
    """Return the common ham band label for these frequencies (3-letter):
       3.5-4.0 MHz   → '80m'
       7.0-7.3 MHz   → '40m'
       14.0-14.35    → '20m'
       21.0-21.45    → '15m'
       28.0-29.7     → '10m'
       50-54         → '6m'
       144-148       → '2m'
       420-450       → '70cm'
       otherwise raise ValueError."""
    ...
```

Save your code to `antenna.py` in the workspace root. The rubric will spot-check several known frequencies including the canonical 7.150 MHz (40m), 14.250 MHz (20m), and 146.520 MHz (2m simplex).
