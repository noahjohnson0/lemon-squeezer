"""Name field validation (a plain required + length-bounded text field).

NOTE: this module duplicates the "required" guard that also appears in
email_field, phone_field and postcode_field.
"""


def check(value):
    """Validate a name. Returns (ok, error)."""
    # --- required guard (copy #4) ---
    if value is None:
        return (False, "required")
    if not value.strip():
        return (False, "required")
    # --- format check ---
    value = value.strip()
    if len(value) > 100:
        return (False, "invalid name")
    return (True, None)
