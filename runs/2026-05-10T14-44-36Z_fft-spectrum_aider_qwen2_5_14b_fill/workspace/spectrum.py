import numpy as np

def magnitude_spectrum(samples: list[float], fs: float) -> tuple[list[float], list[float]]:
    """Compute the one-sided magnitude spectrum of a real signal.
    Returns (freqs_hz, magnitudes) where len(freqs_hz) == N//2 + 1, freqs_hz[0] == 0,
    freqs_hz[-1] == fs/2, and magnitudes are |FFT| (real-FFT magnitudes)."""
    
    if not samples:
        raise ValueError("Input samples cannot be empty.")
        
    n = len(samples)
    fft_result = np.fft.rfft(samples)
    magnitudes = np.abs(fft_result)
    freqs_hz = fs * np.linspace(0, 0.5, n//2 + 1)

    return freqs_hz.tolist(), magnitudes.tolist()

def dominant_freq(samples: list[float], fs: float) -> float:
    """Return the frequency (Hz) of the largest magnitude bin in the one-sided spectrum,
    EXCLUDING the DC component (bin 0) unless it is the only nonzero magnitude."""
    
    if not samples:
        raise ValueError("Input samples cannot be empty.")
        
    freqs_hz, magnitudes = magnitude_spectrum(samples, fs)
    
    # Exclude the DC component
    non_dc_magnitudes = magnitudes[1:]
    max_index = np.argmax(non_dc_magnitudes) + 1
    
    return freqs_hz[max_index]
