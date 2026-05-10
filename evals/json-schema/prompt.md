Write `jsv.py` exporting:

```python
def validate(instance, schema: dict) -> list[str]:
    """Validate `instance` against a small JSON-Schema-like dict.
    Returns a list of human-readable error messages (empty list = valid).

    Supported keywords (subset):
      type: "object" | "array" | "string" | "integer" | "number" | "boolean" | "null"
      properties: {key: subschema}    # for objects
      required: [key, ...]            # for objects
      items: subschema                # for arrays (homogeneous)
      minItems, maxItems              # for arrays
      minLength, maxLength            # for strings
      minimum, maximum                # for numbers/integers
      enum: [...]                     # exact-match list
      pattern: regex                  # for strings (re.fullmatch)

    Errors should include the JSON-pointer-style path, e.g. ".user.age must be integer".
    Validation continues past the first error (collect all errors)."""
```

Pure stdlib (`re`). Don't pip-install `jsonschema`. Do not raise; return error list.

Create only `jsv.py`. Don't run it.
