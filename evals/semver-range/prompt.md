Write `semver.py` implementing Semantic Versioning 2.0.0 parsing, comparison,
and npm-style range matching. No third-party libraries. Create only `semver.py`.
Don't run it.

## Public API

```python
def parse(v: str) -> tuple:
    """Parse a semver string into (major, minor, patch, prerelease, build).

    - major/minor/patch are ints.
    - prerelease is a tuple of identifiers (str for alphanumeric, int for
      purely-numeric ones), or an empty tuple () when there is no prerelease.
    - build is the build-metadata string ('' when absent). Build metadata is
      parsed but MUST be ignored for all precedence/comparison purposes.

    Accepts an optional leading 'v' (e.g. 'v1.2.3').
    Raise ValueError on anything not matching <major>.<minor>.<patch> with the
    optional -<prerelease> and +<build> suffixes (semver 2.0.0 grammar):
      * missing components ('1', '1.2'),
      * leading zeroes in major/minor/patch ('01.2.3') OR in a numeric
        prerelease identifier ('1.0.0-01'),  but '1.0.0-0' and '1.0.0-rc.0'
        are valid,
      * empty prerelease/build ('1.0.0-', '1.0.0+'),
      * non-alphanumeric/hyphen characters in identifiers.
    """

def compare(a: str, b: str) -> int:
    """Return -1 if a < b, 0 if a == b, 1 if a > b, per semver 2.0.0 precedence.

    Build metadata is ignored. Pre-release versions have LOWER precedence than
    the associated normal version (1.0.0-alpha < 1.0.0). Pre-release identifiers
    are compared left-to-right: numeric identifiers compare numerically, are
    always LOWER than alphanumeric ones, and a larger set of identifiers (when
    all preceding are equal) has HIGHER precedence (1.0.0-alpha < 1.0.0-alpha.1).
    """

def satisfies(version: str, range_str: str) -> bool:
    """Return True if `version` satisfies the npm-style `range_str`."""
```

## Range grammar (npm-compatible)

A range is one or more comparator-sets joined by `||` (logical OR). A version
satisfies the range if it satisfies ANY comparator-set. A comparator-set is a
space-separated list of comparators ALL of which must hold (logical AND). The
empty string `""` and `"*"` match every NON-prerelease version.

Supported comparators / sugar:

- Plain version `1.2.3` means exactly `=1.2.3`.
- Operators: `<`, `<=`, `>`, `>=`, `=` followed by a version.
- **Caret** `^M.m.p`: allow changes that do not modify the left-most non-zero
  component. `^1.2.3` := `>=1.2.3 <2.0.0`; `^0.2.3` := `>=0.2.3 <0.3.0`;
  `^0.0.3` := `>=0.0.3 <0.0.4`. With x-ranges: `^1.x` := `>=1.0.0 <2.0.0`,
  `^0.x` := `>=0.0.0 <1.0.0`, `^0.0.x` := `>=0.0.0 <0.1.0`.
- **Tilde** `~M.m.p`: allow patch-level changes if a minor is specified.
  `~1.2.3` := `>=1.2.3 <1.3.0`; `~1.2` := `>=1.2.0 <1.3.0`;
  `~1` := `>=1.0.0 <2.0.0`; `~0.2.3` := `>=0.2.3 <0.3.0`.
- **Hyphen ranges** `1.2.3 - 2.3.4` := `>=1.2.3 <=2.3.4`. A partial upper bound
  is inclusive at the partial level: `1.2.3 - 2.3` := `>=1.2.3 <2.4.0`;
  `1.2 - 2.3.4` := `>=1.2.0 <=2.3.4`; `1.2.3 - 2` := `>=1.2.3 <3.0.0`.
- **X-ranges** `1.2.x`, `1.2.*`, `1.x`, `1`, `*`: a wildcard or omitted trailing
  component matches any value there. `1.2.x` := `>=1.2.0 <1.3.0`;
  `1.x` := `>=1.0.0 <2.0.0`; `1` := `>=1.0.0 <2.0.0`; `*` := `>=0.0.0`.

## Pre-release handling in ranges (the tricky part)

Follow npm's rule precisely:

1. A version WITH a prerelease tag (e.g. `1.2.3-beta.2`) may satisfy a
   comparator ONLY IF some comparator in the SAME comparator-set has a version
   with the SAME `[major, minor, patch]` AND that comparator's version also has
   a prerelease tag. Example: `1.2.3-beta.2` satisfies `>=1.2.3-beta.1 <1.2.4`
   (the lower bound shares 1.2.3 and carries a prerelease) but does NOT satisfy
   `>=1.0.0 <2.0.0` (no comparator there pins 1.2.3 with a prerelease), nor
   `>1.2.3-beta.1` alone if no upper comparator shares the tuple... but DOES
   satisfy `>=1.2.3-alpha` (shares tuple, has prerelease).
2. A NON-prerelease version compares to comparators normally; prerelease tags on
   comparators still participate in precedence (so `1.2.3` satisfies
   `>1.2.3-beta` and `>=1.2.3-rc.1`).
3. `*`, `""`, and bare wildcards do NOT match prerelease versions.

## Performance

`satisfies` and `compare` must be efficient: parsing is linear in the input
length, and matching does not enumerate the version space. The rubric will call
`satisfies` tens of thousands of times against long `||`-joined ranges and long
prerelease identifier lists; an implementation that is super-linear per call (or
re-parses the range on every comparator the slow way) will time out.

## Acceptance criteria (what the rubric checks)

- `parse` round-trips valid versions and the prerelease/build split is correct
  (numeric identifiers become ints; build is captured but ignored).
- `parse` rejects every malformed input listed above with `ValueError`.
- `compare` implements full 2.0.0 precedence incl. numeric-vs-alphanumeric
  prerelease ordering, the "more identifiers wins" rule, and build-metadata
  being ignored.
- `satisfies` handles caret/tilde/hyphen/x-ranges/comparators/AND/OR exactly as
  specified, including all the zero-component caret/tilde edge cases.
- The npm prerelease gating rule above is enforced in BOTH directions.
- A large batch of `satisfies`/`compare` calls completes within the time bound.
