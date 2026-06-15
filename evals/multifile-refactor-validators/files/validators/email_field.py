"""Email field validation.

NOTE: this module duplicates the "required" guard that also appears in
phone_field, postcode_field and name_field. The copy-pasted blocks have
drifted out of sync over time.
"""

import re

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def check(value):
    """Validate an email address.

    Returns (ok, error). ``error`` is None when ok is True, otherwise a short
    lowercase reason string.
    """
    # --- required guard (copy #1) ---
    if value is None:
        return (False, "required")
    if not value.strip():
        return (False, "required")
    # --- format check ---
    value = value.strip()
    if len(value) > 254:
        return (False, "invalid email")
    if not _EMAIL_RE.match(value):
        return (False, "invalid email")
    return (True, None)
