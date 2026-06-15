"""Phone field validation.

NOTE: this module duplicates the "required" guard that also appears in
email_field, postcode_field and name_field.
"""

import re

# Accepts an optional leading +, then 7-15 digits, allowing spaces, dashes and
# parentheses as separators (which are stripped before counting).
_PHONE_RE = re.compile(r"^\+?\d{7,15}$")


def check(value):
    """Validate a phone number. Returns (ok, error)."""
    # --- required guard (copy #2) ---
    if value is None:
        return (False, "required")
    if not value.strip():
        return (False, "required")
    # --- format check ---
    value = value.strip()
    digits = re.sub(r"[ \-().]", "", value)
    if not _PHONE_RE.match(digits):
        return (False, "invalid phone")
    return (True, None)
