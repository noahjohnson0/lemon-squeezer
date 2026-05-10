import numpy as np

def magnitude_spectrum(samples: list[float], fs: float) -> tuple[list[float], list[float]]:
    """Compute the one-sided magnitude spectrum of a real signal.
    Returns (freqs_hz, magnitudes) where len(freqs_hz) == N//2 + 1, freqs_hz[0] == 0,
    freqs_hz[-1] == fs/2, and magnitudes are |FFT| (real-FFT magnitudes)."""
    if not samples:
        raise ValueError("Input signal must be non-empty")

    n = len(samples)
    fft_vals = np.fft.rfft(samples)

    freqs_hz = np.fft.rfftfreq(n, 1/fs)
    magnitudes = np.abs(fft_vals)

    return list(freqs_hz), list(magnitudes)

def dominant_freq(samples: list[float], fs: float) -> float:
    """Return the frequency (Hz) of the largest magnitude bin in the one-sided spectrum,
    EXCLUDING the DC component (bin 0) unless it is the only nonzero magnitude."""
    if not samples:
        raise ValueError("Input signal must be non-empty")

    freqs_hz, magnitudes = magnitude_spectrum(samples, fs)

    # Exclude the DC component
    if len(magnitudes) > 1 and magnitudes[1:] == [0]:
        return freqs_hz[0]

    max_magnitude_index = np.argmax(magnitudes)
    dominant_frequency = freqs_hz[max_magnitude_index]
    return dominant_frequency
