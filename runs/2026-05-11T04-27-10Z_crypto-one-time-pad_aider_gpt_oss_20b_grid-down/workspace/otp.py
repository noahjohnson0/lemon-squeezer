"""
One-Time Pad (OTP) implementation.

This module provides simple XOR-based encryption and decryption functions
for the One-Time Pad cipher, along with utilities for key generation
and hexadecimal encoding/decoding.

The OTP is provably unbreakable when the key is truly random,
the same length as the message, used only once, and kept secret.
"""

import secrets
from typing import Iterable


def xor_encrypt(plaintext: bytes, key: bytes) -> bytes:
    """
    Encrypt by XORing each byte of the plaintext with the corresponding byte of the key.

    Parameters
    ----------
    plaintext : bytes
        The data to encrypt.
    key : bytes
        The key to use for encryption. Must be exactly the same length as ``plaintext``.

    Returns
    -------
    bytes
        The resulting ciphertext.

    Raises
    ------
    ValueError
        If ``key`` is not the same length as ``plaintext``.
    """
    if len(plaintext) != len(key):
        raise ValueError("Key must be exactly the same length as plaintext.")
    # XOR each byte; for empty plaintext this returns an empty bytes object.
    return bytes(a ^ b for a, b in zip(plaintext, key))


def xor_decrypt(ciphertext: bytes, key: bytes) -> bytes:
    """
    Decrypt ciphertext encrypted with :func:`xor_encrypt`.

    Parameters
    ----------
    ciphertext : bytes
        The data to decrypt.
    key : bytes
        The key that was used for encryption. Must be exactly the same length as ``ciphertext``.

    Returns
    -------
    bytes
        The original plaintext.

    Raises
    ------
    ValueError
        If ``key`` is not the same length as ``ciphertext``.
    """
    # Decryption is identical to encryption for XOR.
    return xor_encrypt(ciphertext, key)


def generate_key(length: int) -> bytes:
    """
    Generate a cryptographically secure random key of the specified length.

    Parameters
    ----------
    length : int
        The desired length of the key in bytes.

    Returns
    -------
    bytes
        A sequence of ``length`` random bytes.
    """
    if length < 0:
        raise ValueError("Length must be non-negative.")
    return secrets.token_bytes(length)


def hex_encode(data: bytes) -> str:
    """
    Convert binary data to a colon-free lowercase hexadecimal string.

    Parameters
    ----------
    data : bytes
        The binary data to encode.

    Returns
    -------
    str
        The hexadecimal representation of ``data``.
    """
    return data.hex()


def hex_decode(s: str) -> bytes:
    """
    Convert a hexadecimal string back to binary data.

    Parameters
    ----------
    s : str
        The hexadecimal string to decode. Must contain only valid hex digits.

    Returns
    -------
    bytes
        The decoded binary data.
    """
    return bytes.fromhex(s)
