"""
Implementation of the classical Vigenère cipher.

Functions
---------
encrypt(plaintext: str, key: str) -> str
    Encrypts the plaintext using the provided key.

decrypt(ciphertext: str, key: str) -> str
    Decrypts the ciphertext using the provided key.

Both functions raise ValueError if the key is empty after removing
whitespace or contains any character that is not a letter or whitespace.
"""

import string


def _validate_and_prepare_key(key: str):
    """
    Validate the key and return a list of shift values (0-25).

    Parameters
    ----------
    key : str
        The key string. May contain letters and whitespace.

    Returns
    -------
    List[int]
        List of shift values corresponding to each letter in the key.

    Raises
    ------
    ValueError
        If the key contains invalid characters or has no letters.
    """
    if not isinstance(key, str):
        raise ValueError("Key must be a string")

    # Filter out whitespace and validate characters
    cleaned = []
    for ch in key:
        if ch.isspace():
            continue
        if ch.isalpha():
            cleaned.append(ch.upper())
        else:
            raise ValueError("Key contains invalid characters; only letters and whitespace are allowed")

    if not cleaned:
        raise ValueError("Key must contain at least one letter")

    # Convert letters to shift values
    shifts = [ord(ch) - ord('A') for ch in cleaned]
    return shifts


def _shift_char(ch: str, shift: int, encrypt: bool = True) -> str:
    """
    Shift a single alphabetic character by the given shift amount.

    Parameters
    ----------
    ch : str
        The character to shift. Must be a letter.
    shift : int
        The shift amount (0-25).
    encrypt : bool, optional
        If True, perform encryption (add shift). If False, perform decryption (subtract shift).

    Returns
    -------
    str
        The shifted character, preserving original case.
    """
    if not ch.isalpha():
        return ch

    base = ord('A') if ch.isupper() else ord('a')
    offset = ord(ch) - base
    if encrypt:
        new_offset = (offset + shift) % 26
    else:
        new_offset = (offset - shift) % 26
    return chr(base + new_offset)


def encrypt(plaintext: str, key: str) -> str:
    """
    Encrypt the plaintext using the Vigenère cipher.

    Parameters
    ----------
    plaintext : str
        The text to encrypt.
    key : str
        The encryption key. Must contain at least one letter and only letters or whitespace.

    Returns
    -------
    str
        The ciphertext.

    Raises
    ------
    ValueError
        If the key is invalid.
    """
    shifts = _validate_and_prepare_key(key)
    ciphertext = []
    key_len = len(shifts)
    key_index = 0

    for ch in plaintext:
        if ch.isalpha():
            shift = shifts[key_index % key_len]
            ciphertext.append(_shift_char(ch, shift, encrypt=True))
            key_index += 1
        else:
            ciphertext.append(ch)

    return ''.join(ciphertext)


def decrypt(ciphertext: str, key: str) -> str:
    """
    Decrypt the ciphertext using the Vigenère cipher.

    Parameters
    ----------
    ciphertext : str
        The text to decrypt.
    key : str
        The decryption key. Must contain at least one letter and only letters or whitespace.

    Returns
    -------
    str
        The plaintext.

    Raises
    ------
    ValueError
        If the key is invalid.
    """
    shifts = _validate_and_prepare_key(key)
    plaintext = []
    key_len = len(shifts)
    key_index = 0

    for ch in ciphertext:
        if ch.isalpha():
            shift = shifts[key_index % key_len]
            plaintext.append(_shift_char(ch, shift, encrypt=False))
            key_index += 1
        else:
            plaintext.append(ch)

    return ''.join(plaintext)
