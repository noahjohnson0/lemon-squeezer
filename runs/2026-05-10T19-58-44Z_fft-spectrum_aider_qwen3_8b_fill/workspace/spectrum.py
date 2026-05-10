import numpy as np
from numpy.fft import rfft

def magnitude_spectrum(samples: list[float], fs: float) -> tuple[list[float], list[float]]:
    """Compute the one-sided magnitude spectrum of a real signal.
    Returns (freqs_hz, magnitudes) where len(freqs_hz) == N//2 + 1, freqs_hz[0] == 0,
    freqs_hz[-1] == fs/2, and magnitudes are |FFT| (real-FFT magnitudes)."""
    if len(samples) == 0:
        raise ValueError("Input samples cannot be empty.")
    N = len(samples)
    fft_result = rfft(samples)
    magnitudes = np.abs(fft_result)
    freqs_hz = np.linspace(0, fs / 2, N // 2 + 1)
    return (freqs_hz.tolist(), magnitudes.tolist())

def dominant_freq(samples: list[float], fs: float) -> float:
    """Return the frequency (Hz) of the largest magnitude bin in the one-sided spectrum,
    EXCLUDING the DC component (bin 0) unless it is the only nonzero magnitude."""
    freqs_hz, magnitudes = magnitude_spectrum(samples, fs)
    if len(magnitudes) == 1:
        return freqs_hz[0]
    other_magnitudes = magnitudes[1:]
    if np.allclose(other_magnitudes, 0):
        return freqs_hz[0]
    max_index = np.argmax(other_magnitudes)
    return freqs_hz[1 + max_index]
