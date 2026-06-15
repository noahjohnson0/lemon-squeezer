Write `config.py` exporting a single function `loads(text: str) -> dict` that parses an
INI/TOML-lite configuration format. Implement the parser BY HAND (no `configparser`,
no `toml`/`tomllib`, no `json`, no `ast.literal_eval`, no third-party libs). Standard
library helpers like `str.split` are fine; the point is to write the scanner yourself.

```python
def loads(text: str) -> dict:
    """Parse INI/TOML-lite config text into a nested dict. See spec below.
    Raise ConfigError (a ValueError subclass you define) on malformed input."""
```

You MUST also define and export the exception class:

```python
class ConfigError(ValueError):
    ...
```

## Grammar

The input is a sequence of lines. Parsing is line-oriented (after continuations
are joined, see below).

### Sections

A line of the form `[name]` opens a section. The section name may be **dotted** to
create nesting: `[a.b.c]` means the dict `{"a": {"b": {"c": {...}}}}`. Keys that
follow a section header (until the next header) are placed in that section's dict.

- Keys before any section header go at the **top level** of the returned dict.
- Section names are stripped of surrounding whitespace: `[ a.b ]` == `[a.b]`.
- Each dotted component is stripped: `[a . b]` == `[a.b]`.
- An empty section name `[]`, an empty component (`[a..b]`, `[a.]`, `[.b]`), or a
  header with trailing junk after the `]` (`[a] x`) is a `ConfigError`.
- Re-opening the SAME fully-qualified section later (a second `[a.b]`) is a
  `ConfigError` (duplicate section).
- A nested section MAY appear even if its parent was never declared:
  `[a.b]` alone yields `{"a": {"b": {}}}`.
- If a section path collides with an already-set scalar key (e.g. `x=1` at top
  level then `[x.y]`), that is a `ConfigError`.

### Key/value lines

`key = value`. The key is everything left of the first unquoted `=`, stripped.
The value is everything right of it, stripped (after comment removal). A line with
no `=` (and that is not blank, a comment, or a section header) is a `ConfigError`
(malformed line). An empty key (`= 5`) is a `ConfigError`.

A duplicate key **within the same section** is a `ConfigError`. (The same key name
in two different sections is fine.)

### Value type coercion

After extracting the raw (stripped, comment-free) value text, coerce in this order:

1. If the value is a **quoted string** (see below), it is a string with quotes and
   escapes processed. Coercion stops; it stays a string even if the contents look
   numeric (`"42"` -> the string `42`).
2. `true` / `false` (case-insensitive: `True`, `FALSE`, ...) -> Python `bool`.
3. An integer: optional leading `+`/`-` then digits, e.g. `42`, `-7`, `+0`.
   Underscores are NOT allowed (`1_000` is a string). A leading-zero multi-digit
   token (`007`) stays a **string**, not an int.
4. A float: decimal (`3.14`, `-0.5`, `.5`, `2.`) or scientific (`1e9`, `6.02e23`,
   `-1.5E-3`). `inf`/`nan` tokens stay strings.
5. Otherwise it is an **unquoted string** (kept verbatim, already stripped).
   An empty value (`key =` with nothing after) is the empty string `""`.

### Quoted strings

A value is "quoted" only if, after stripping, it **starts** with `"` or `'`. The
matching closing quote must be the LAST character; trailing non-whitespace after
the closing quote is a `ConfigError`.

- Double-quoted strings process backslash escapes: `\n` (newline), `\t` (tab),
  `\r`, `\\` (backslash), `\"` (quote), `\'` (quote). An unknown escape such as
  `\x` is a `ConfigError`. A backslash at end-of-string (unterminated escape) is
  a `ConfigError`.
- Single-quoted strings are **raw**: no escapes are processed, so `'a\nb'` is the
  five characters `a \ n b`... i.e. backslash is literal. A single-quoted string
  cannot contain a single quote (there is no escaping), and an unterminated
  single-quoted string is a `ConfigError`.
- An unterminated double-quoted string (no closing quote) is a `ConfigError`.

### Comments

`#` and `;` begin a comment that runs to end of line. BUT a comment marker inside
a quoted string is literal, not a comment:

- `key = "a # b"` -> the string `a # b` (the `#` is inside quotes).
- `key = value # trailing` -> the string `value` (comment stripped, then
  whitespace stripped).
- `key = "x" # c` -> the string `x` (comment after the closing quote is stripped).
- `key = ab ; cd` -> the string `ab`.
- A line that is only a comment (after optional leading whitespace) is ignored.
- `#` / `;` only start a comment when **preceded by whitespace or at start of the
  value/line**, OR outside quotes generally; specifically, inside an UNquoted
  value a `#`/`;` always starts a comment (so `key = a#b` -> `a`). Inside quotes
  it never does.
- Blank lines are ignored.

### Line continuations

A line whose raw text ends with a single backslash `\` (the line-continuation
marker) is joined with the next line: the trailing `\` and the newline are removed
and the following line's text is appended directly (no space inserted).
Continuations are resolved BEFORE comment and quote processing. A trailing `\`
on the very last line (nothing to continue into) is a `ConfigError`.

Note the interaction: a backslash that is the last non-newline character of the
**physical** line is a continuation; this is distinct from escapes inside a
double-quoted string, which are handled after joining.

## Performance

`loads` must be linear-ish: O(n) in the input length. The rubric feeds a large
input (tens of thousands of lines / a value with a very long run of comment-like
characters) and requires it to parse within a few seconds. A quadratic scanner
(e.g. repeated `s = s[1:]` slicing or re-scanning the whole remaining string per
character) will time out.

## Output

`loads` returns a plain nested `dict`. Booleans are `bool`, ints are `int`, floats
are `float`, strings are `str`. Create only `config.py`. Do not print anything.
