"""
Antenna calculations for amateur (ham) radio operators.

Functions:
    wavelength_m(freq_mhz: float) -> float
    dipole_total_length(freq_mhz: float) -> float
    dipole_leg_length(freq_mhz: float) -> float
    quarter_wave_vertical_m(freq_mhz: float) -> float
    band_for_frequency(freq_mhz: float) -> str
"""

from __future__ import annotations

# Speed of light in m/s (not used directly but kept for reference)
C = 299_792_458

# Practical velocity factor for thin wire (accounts for insulation and end effects)
VELOCITY_FACTOR = 0.95


def wavelength_m(freq_mhz: float) -> float:
    """
    Return the free‑space wavelength in meters for a given frequency in MHz.
    Uses the practical conversion 300 / f(MHz) ≈ λ(m).
    """
    if freq_mhz <= 0:
        raise ValueError("Frequency must be positive")
    return 300.0 / freq_mhz


def dipole_total_length(freq_mhz: float) -> float:
    """
    Return the practical total length (both legs together) of a half‑wave dipole
    in meters.  The free‑space half‑wave length is λ/2; multiply by VELOCITY_FACTOR.
    """
    return (wavelength_m(freq_mhz) / 2.0) * VELOCITY_FACTOR


def dipole_leg_length(freq_mhz: float) -> float:
    """
    Return the length of one leg of a half‑wave dipole in meters.
    """
    return dipole_total_length(freq_mhz) / 2.0


def quarter_wave_vertical_m(freq_mhz: float) -> float:
    """
    Return the practical length of a quarter‑wave vertical monopole over a ground plane
    in meters.  The free‑space quarter‑wave length is λ/4; multiply by VELOCITY_FACTOR.
    """
    return (wavelength_m(freq_mhz) / 4.0) * VELOCITY_FACTOR


def band_for_frequency(freq_mhz: float) -> str:
    """
    Return the common ham band label (3‑letter) for a given frequency in MHz.
    Raises ValueError if the frequency does not fall within a known band.
    """
    bands = [
        (3.5, 4.0, "80m"),
        (7.0, 7.3, "40m"),
        (14.0, 14.35, "20m"),
        (21.0, 21.45, "15m"),
        (28.0, 29.7, "10m"),
        (50.0, 54.0, "6m"),
        (144.0, 148.0, "2m"),
        (420.0, 450.0, "70cm"),
    ]

    for lower, upper, label in bands:
        if lower <= freq_mhz <= upper:
            return label

    raise ValueError(f"Frequency {freq_mhz} MHz is not within a known ham band")
