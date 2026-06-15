"""formfields — a tiny form-field validation package.

Public API lives in ``validators.api`` (re-exported here):

    from validators import validate, is_valid

    ok, err = validate("email", "a@b.com")   # -> (True, None)
    ok, err = validate("phone", "")          # -> (False, "required")
    is_valid("postcode", "SW1A 1AA")         # -> True
"""

from .api import validate, is_valid, FIELD_KINDS

__all__ = ["validate", "is_valid", "FIELD_KINDS"]
