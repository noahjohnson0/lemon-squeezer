import numpy as np

def magnitude_spectrum(samples: list[float], fs: float) -> tuple[list[float], list[float]]:
    """
    Compute the one-sided magnitude spectrum of a real signal.
    Returns (freqs_hz, magnitudes) where len(freqs_hz) == N//2 + 1,
    freqs_hz[0] == 0, freqs_hz[-1] == fs/2, and magnitudes are |FFT| (real-FFT magnitudes).
    """
    if not samples:
        raise ValueError("Input samples must not be empty.")
    samples_np = np.asarray(samples, dtype=float)
    N = samples_np.size
    # Compute one-sided FFT
    fft_vals = np.fft.rfft(samples_np)
    magnitudes = np.abs(fft_vals)
    freqs = np.fft.rfftfreq(N, d=1.0 / fs)
    return freqs.tolist(), magnitudes.tolist()

def dominant_freq(samples: list[float], fs: float) -> float:
    """
    Return the frequency (Hz) of the largest magnitude bin in the one-sided spectrum,
    EXCLUDING the DC component (bin 0) unless it is the only nonzero magnitude.
    """
    freqs, magnitudes = magnitude_spectrum(samples, fs)
    # Convert to numpy arrays for easier indexing
    mags_np = np.asarray(magnitudes)
    # If all non-DC bins are zero, return DC frequency (0 Hz)
    if np.all(mags_np[1:] == 0):
        return 0.0
    # Find index of maximum magnitude excluding DC
    idx = np.argmax(mags_np[1:]) + 1  # offset by 1 to skip DC
    return freqs[idx]
