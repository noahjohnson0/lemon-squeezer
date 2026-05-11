import numpy as np

def magnitude_spectrum(samples: list[float], fs: float) -> tuple[list[float], list[float]]:
    """Compute the one-sided magnitude spectrum of a real signal.
    Returns (freqs_hz, magnitudes) where len(freqs_hz) == N//2 + 1, freqs_hz[0] == 0,
    freqs_hz[-1] == fs/2, and magnitudes are |FFT| (real-FFT magnitudes)."""
    if not samples:
        raise ValueError("Input list cannot be empty")
    fft = np.fft.rfft(samples)
    freqs_hz = np.fft.rfftfreq(len(samples), 1/fs)
    return freqs_hz, np.abs(fft)

def dominant_freq(samples: list[float], fs: float) -> float:
    """Return the frequency (Hz) of the largest magnitude bin in the one-sided spectrum,
    EXCLUDING the DC component (bin 0) unless it is the only nonzero magnitude."""
    freqs_hz, magnitudes = magnitude_spectrum(samples, fs)
    max_idx = np.argmax(magnitudes[1:]) + 1
    return freqs_hz[max_idx]
