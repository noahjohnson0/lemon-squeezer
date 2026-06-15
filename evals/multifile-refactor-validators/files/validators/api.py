"""Public API for the formfields package.

This module is the stable, public surface. Callers depend on:

    validate(kind, value) -> (ok: bool, error: str | None)
    is_valid(kind, value) -> bool
    FIELD_KINDS           -> tuple of supported kind strings

Keep these signatures and return shapes identical across any refactor.
"""

from . import email_field, phone_field, postcode_field, name_field

FIELD_KINDS = ("email", "phone", "postcode", "name")

_DISPATCH = {
    "email": email_field.check,
    "phone": phone_field.check,
    "postcode": postcode_field.check,
    "name": name_field.check,
}


def validate(kind, value):
    """Validate ``value`` as field type ``kind``.

    Returns a ``(ok, error)`` tuple. ``error`` is ``None`` when valid,
    otherwise a short lowercase reason string. Raises ``ValueError`` for an
    unknown ``kind``.
    """
    if kind not in _DISPATCH:
        raise ValueError("unknown field kind: %r" % (kind,))
    return _DISPATCH[kind](value)


def is_valid(kind, value):
    """Return True iff ``value`` is a valid ``kind`` field."""
    ok, _ = validate(kind, value)
    return ok
