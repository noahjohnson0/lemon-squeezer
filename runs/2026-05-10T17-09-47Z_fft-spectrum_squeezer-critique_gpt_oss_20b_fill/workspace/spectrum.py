"""Spectrum analysis utilities.

This module provides convenient functions for computing the one‑sided magnitude
spectrum of a real signal and for identifying the dominant frequency.

The implementation relies on :mod:`numpy` and uses ``numpy.fft.rfft``.  The
functions are tolerant of Python lists as input but they internally convert
to :class:`numpy.ndarray` for efficient computation.

The module is intentionally lightweight and does not perform any scaling
of the FFT output – it simply returns the absolute values of the real FFT.
"""

from __future__ import annotations

import numpy as np

__all__ = ["magnitude_spectrum", "dominant_freq"]


def magnitude_spectrum(samples: list[float], fs: float) -> tuple[list[float], list[float]]:
    """Compute the one‑sided magnitude spectrum of a real signal.

    Parameters
    ----------
    samples:
        The real‑valued time‑domain samples.
    fs:
        Sampling frequency in Hz.

    Returns
    -------
    tuple[list[float], list[float]]
        ``(freqs_hz, magnitudes)`` where ``freqs_hz`` has length
        ``N // 2 + 1`` and
        ``freqs_hz[0] == 0`` and ``freqs_hz[-1] == fs / 2``.
        The corresponding magnitude spectrum is the magnitude of the real
        FFT ``np.abs(np.fft.rfft(samples))``.

    Raises
    ------
    ValueError
        If ``samples`` is empty.
    """
    # Input validation
    if not samples:
        raise ValueError("'samples' must contain at least one element")

    # Ensure an array of floats
    x = np.asarray(samples, dtype=float)
    N = x.size

    # Compute one‑sided spectrum and corresponding frequencies
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(N, d=1 / fs)
    magnitudes = np.abs(spectrum)

    # Ensure the last frequency is exactly fs/2 for both even and odd N
    # For odd N, the last bin from rfftfreq is slightly below fs/2;
    # we replace it with fs/2 while keeping the magnitude the same.
    if N % 2 == 1:
        freqs = freqs.copy()
        if freqs.size > 0:
            freqs[-1] = fs / 2

    return freqs.tolist(), magnitudes.tolist()


def dominant_freq(samples: list[float], fs: float) -> float:
    """Return the dominant frequency of a real signal.

    The function computes the one‑sided magnitude spectrum and returns the
    frequency (in Hz) of the largest magnitude bin, **excluding the DC
    component** (index 0) unless it is the only non‑zero magnitude.

    Parameters
    ----------
    samples:
        The real‑valued time‑domain samples.
    fs:
        Sampling frequency in Hz.

    Returns
    -------
    float
        The frequency of the dominant non‑DC component, or 0.0 if the DC
        component is the only non‑zero magnitude.

    Raises
    ------
    ValueError
        If ``samples`` is empty.
    """
    freqs, mags = magnitude_spectrum(samples, fs)
    if not freqs:
        # This should never happen because magnitude_spectrum would have
        # raised an error for an empty input.
        raise ValueError("Unexpected empty spectrum")

    # Convert to numpy arrays for efficient operations
    mags_np = np.asarray(mags)
    freqs_np = np.asarray(freqs)

    # Determine if all non‑DC bins are zero (within a small tolerance)
    non_dc_mags = mags_np[1:]
    if np.allclose(non_dc_mags, 0, atol=1e-12):
        # DC is either non‑zero or all bins are zero – in both cases we return 0 Hz
        return float(freqs_np[0])

    # Find the index of the largest magnitude among non‑DC bins
    idx_non_dc = np.argmax(non_dc_mags) + 1  # +1 to offset the DC exclusion
    return float(freqs_np[idx_non_dc])

"""End of file."""
