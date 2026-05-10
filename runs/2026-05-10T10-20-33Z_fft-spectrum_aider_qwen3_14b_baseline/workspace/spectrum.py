import numpy as np

def magnitude_spectrum(samples: list[float], fs: float) -> tuple[list[float], list[float]]:
    """Compute the one-sided magnitude spectrum of a real signal.
    Returns (freqs_hz, magnitudes) where len(freqs_hz) == N//2 + 1, freqs_hz[0] == 0,
    freqs_hz[-1] == fs/2, and magnitudes are |FFT| (real-FFT magnitudes)."""
    if not samples:
        raise ValueError("Input samples cannot be empty.")
    N = len(samples)
    fft_result = np.fft.rfft(samples)
    magnitudes = np.abs(fft_result)
    freqs_hz = np.linspace(0, fs / 2, len(magnitudes))
    return freqs_hz.tolist(), magnitudes.tolist()

def dominant_freq(samples: list[float], fs: float) -> float:
    """Return the frequency (Hz) of the largest magnitude bin in the one-sided spectrum,
    EXCLUDING the DC component (bin 0) unless it is the only nonzero magnitude."""
    freqs_hz, magnitudes = magnitude_spectrum(samples, fs)
    # Exclude DC component (index 0)
    magnitudes_without_dc = magnitudes[1:]
    freqs_without_dc = freqs_hz[1:]
    if len(magnitudes_without_dc) == 0:
        # All magnitudes are DC, return 0 Hz
        return 0.0
    # Check if all non-DC magnitudes are zero
    if np.allclose(magnitudes_without_dc, 0.0):
        return 0.0
    # Find the index of the maximum magnitude
    max_index = np.argmax(magnitudes_without_dc)
    return freqs_without_dc[max_index]
