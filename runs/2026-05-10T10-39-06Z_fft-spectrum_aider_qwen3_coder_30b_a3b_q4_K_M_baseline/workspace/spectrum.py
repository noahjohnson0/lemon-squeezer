import numpy as np

def magnitude_spectrum(samples: list[float], fs: float) -> tuple[list[float], list[float]]:
    """Compute the one-sided magnitude spectrum of a real signal.
    Returns (freqs_hz, magnitudes) where len(freqs_hz) == N//2 + 1, freqs_hz[0] == 0,
    freqs_hz[-1] == fs/2, and magnitudes are |FFT| (real-FFT magnitudes)."""
    if not samples:
        raise ValueError("Input samples cannot be empty")
    
    n = len(samples)
    fft_result = np.fft.rfft(samples)
    magnitudes = np.abs(fft_result)
    
    # Create frequency bins
    freqs_hz = np.fft.rfftfreq(n, 1/fs)
    
    return (freqs_hz.tolist(), magnitudes.tolist())

def dominant_freq(samples: list[float], fs: float) -> float:
    """Return the frequency (Hz) of the largest magnitude bin in the one-sided spectrum,
    EXCLUDING the DC component (bin 0) unless it is the only nonzero magnitude."""
    if not samples:
        raise ValueError("Input samples cannot be empty")
    
    freqs_hz, magnitudes = magnitude_spectrum(samples, fs)
    
    # Find the index of the maximum magnitude (excluding DC component)
    # If all magnitudes except DC are zero, we return DC
    max_idx = 0
    max_mag = magnitudes[0]
    
    # Check if there are any non-zero magnitudes (excluding DC)
    non_dc_magnitudes = magnitudes[1:]
    if any(m > 0 for m in non_dc_magnitudes):
        # Find max among non-DC magnitudes
        max_idx = 1 + non_dc_magnitudes.index(max(non_dc_magnitudes))
        max_mag = non_dc_magnitudes[max_idx - 1]
    else:
        # All non-DC magnitudes are zero, return DC
        max_idx = 0
    
    return freqs_hz[max_idx]
