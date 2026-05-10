"""Utility functions for common engineering calculations.

This module provides a handful of small pure‑function helpers that are
frequently used in introductory physics, electrical engineering and fluid
mechanics courses.  All calculations are explicit, type annotated and do
not rely on any external packages.

The functions are intentionally simple:

* ``reynolds``   – Computes the Reynolds number.
* ``beam_deflection_max`` – Computes the maximum deflection of a simply
  supported beam with a centre point load.
* ``rc_time_constant`` – Computes the RC time constant.
* ``voltage_divider`` – Computes the output of a two‑resistor divider.

No side effects, no I/O – the module is fully testable and importable
without any dependencies.
"""

from __future__ import annotations

__all__ = [
    "reynolds",
    "beam_deflection_max",
    "rc_time_constant",
    "voltage_divider",
]


+def reynolds(rho: float, v: float, L: float, mu: float) -> float:
+    """Return the Reynolds number.
+
+    Parameters
+    ----------
+    rho:
+        Fluid density in kilograms per cubic metre (kg/m³).
+    v:
+        Flow velocity in metres per second (m/s).
+    L:
+        Characteristic length in metres (m).
+    mu:
+        Dynamic viscosity in Pascal seconds (Pa·s).
+
+    Returns
+    -------
+    float
+        Dimensionless Reynolds number ``Re = rho * v * L / mu``.
+    """
+    return rho * v * L / mu
+
+
+def beam_deflection_max(P: float, L: float, E: float, I: float) -> float:
+    """Return the maximum deflection of a simply supported beam.
+
+    The analytical expression for a centre‑point load ``P`` on a beam of
+    span ``L`` is : ``Δmax = P * L**3 / (48 * E * I)``.
+
+    Parameters
+    ----------
+    P:
+        Point load in newtons (N).
+    L:
+        Span length in metres (m).
+    E:
+        Young's modulus in pascals (Pa).
+    I:
+        Second moment of area in metres to the fourth power (m⁴).
+
+    Returns
+    -------
+    float
+        Maximum deflection in metres (m).
+    """
+    return P * L**3 / (48.0 * E * I)
+
+
+def rc_time_constant(R: float, C: float) -> float:
+    """Return the RC time constant.
+
+    Parameters
+    ----------
+    R:
+        Resistance in ohms (Ω).
+    C:
+        Capacitance in farads (F).
+
+    Returns
+    -------
+    float
+        Time constant in seconds (s).
+    """
+    return R * C
+
+
+def voltage_divider(vin: float, r1: float, r2: float) -> float:
+    """Return the voltage at the junction of a two‑resistor divider.
+
+    The formula for a series divider is ``Vout = Vin * R2 / (R1 + R2)``.
+
+    Parameters
+    ----------
+    vin:
+        Input voltage in volts (V).
+    r1:
+        First resistor in ohms (Ω).
+    r2:
+        Second resistor in ohms (Ω).
+
+    Returns
+    -------
+    float
+        Output voltage in volts.
+    """
+    return vin * r2 / (r1 + r2)
+
*** End of File ***"
