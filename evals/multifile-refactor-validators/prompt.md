# Refactor the `validators` form-field package

The `validators/` package validates form fields. There are four field modules —
`email_field.py`, `phone_field.py`, `postcode_field.py`, `name_field.py` — and a
public API module `api.py`. Each field module exposes a `check(value)` function
returning a `(ok, error)` tuple, where `error` is `None` when valid and
otherwise a short lowercase reason string (e.g. `"required"`, `"invalid email"`).

Two problems:

1. **Duplication.** The "required" guard — the block that rejects missing or
   blank input with the error `"required"` — has been copy-pasted into all four
   field modules. That duplicated logic should live in **one** shared place.

2. **An inconsistency / bug.** Because the guard was copy-pasted, the copies
   drifted. The fields do **not** all treat blank input the same way: a
   whitespace-only value (e.g. `"   "`) is reported as `"required"` by some
   fields but slips past the guard in another field and gets reported with a
   different error instead. Every field must treat a value that is `None`,
   empty, or whitespace-only **identically**: as `(False, "required")`.

## What to do

- Extract the shared "required" guard into a **new shared module** inside the
  package (for example `validators/common.py` with a helper like
  `required(value)`), and have all four field modules use it instead of their
  own copy. No field module should keep its own copy-pasted required block.
- Fix the inconsistency so that for **every** field kind, a `None`, empty, or
  whitespace-only value returns exactly `(False, "required")`.
- Keep the **public API identical**. After your change the following must still
  hold (same import paths, same call signatures, same return shapes):

  ```python
  from validators import validate, is_valid, FIELD_KINDS

  validate("email", "a@b.com")        # (True, None)
  validate("phone", "+1 (555) 123-4567")  # (True, None)
  validate("postcode", "SW1A 1AA")    # (True, None)
  validate("name", "Ada Lovelace")    # (True, None)

  validate("phone", "")               # (False, "required")
  validate("postcode", "   ")         # (False, "required")   <-- currently wrong
  is_valid("email", "nope")           # False
  validate("nope", "x")               # raises ValueError
  ```

  Valid inputs must stay valid and format errors (`"invalid email"`,
  `"invalid phone"`, `"invalid postcode"`, `"invalid name"`) must keep their
  existing messages.

Edit the files in place under `validators/`.
