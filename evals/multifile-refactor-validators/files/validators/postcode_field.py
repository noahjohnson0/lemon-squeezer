"""Postcode (UK) field validation.

NOTE: this module duplicates the "required" guard that also appears in
email_field, phone_field and name_field.
"""

import re

# Simplified UK postcode pattern, case-insensitive, single space tolerated.
_POSTCODE_RE = re.compile(r"^[A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2}$", re.IGNORECASE)


def check(value):
    """Validate a UK postcode. Returns (ok, error)."""
    # --- required guard (copy #3) ---
    if not value:
        return (False, "required")
    # --- format check ---
    value = value.strip()
    if not _POSTCODE_RE.match(value):
        return (False, "invalid postcode")
    return (True, None)
