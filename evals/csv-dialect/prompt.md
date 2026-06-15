Write a CSV reader/writer in a module named `csvdialect.py` that correctly handles the
RFC-4180-style dialect with a configurable delimiter and quote character. Implement
exactly two top-level functions (no class required):

```python
def parse(text, delimiter=',', quote='"') -> list[list[str]]: ...
def dump(rows, delimiter=',', quote='"') -> str: ...
```

Do NOT use the standard-library `csv` module. Implement the parsing/quoting by hand.
Create only `csvdialect.py`. Don't run it.

## parse(text, delimiter, quote)

Returns a list of records; each record is a list of string fields. Rules:

1. Records are separated by line breaks. Accept `\n`, `\r\n`, AND a bare `\r` as a
   record separator (normalize all three). A line break that occurs INSIDE a quoted
   field is a literal character of that field, NOT a record separator.
2. Fields are separated by `delimiter`. A `delimiter` inside a quoted field is literal.
3. A field may be quoted by wrapping it in the `quote` char. Inside a quoted field, two
   consecutive quote chars (`""`) denote a single literal quote char.
4. A quoted field ends at the first lone quote char; what follows must be a delimiter,
   a line break, or end-of-text.
5. Empty input (`""`) yields `[]` (no records). Input that is only a trailing line
   break after data does NOT create a trailing empty record: `"a,b\n"` -> `[["a","b"]]`.
   But a blank line BETWEEN records is a real record with one empty field:
   `"a\n\nb"` -> `[["a"],[""],["b"]]`.
6. Empty fields are preserved: `"a,,c"` -> `[["a","","c"]]`; `","` -> `[["",""]]`;
   a quoted empty field `'""'` -> `[[""]]`.
7. Leading/trailing spaces are significant and never stripped: `" a , b "` ->
   `[[" a "," b "]]`.
8. `parse` must run in LINEAR time / O(n) in the length of the input. A 200k-field
   single-record input must parse in well under a couple of seconds; quadratic
   string-rebuilding (e.g. `field = field + ch` on a growing str inside the hot loop
   is fine, but slicing/concatenating the whole remaining text each step is not) will
   time out and is considered wrong.

## dump(rows, delimiter, quote)

The inverse of `parse`. Given a list of records (lists of string fields), return a single
string. Rules:

1. Join fields with `delimiter`, join records with `\n`, and terminate the output with a
   trailing `\n` (so `dump([["a","b"]])` -> `"a,b\n"`). `dump([])` -> `""`.
2. Quote a field IF AND ONLY IF it contains the `delimiter`, the `quote` char, a `\n`, or
   a `\r`. Fields that need no quoting are emitted bare (do NOT quote everything).
3. When quoting, wrap in `quote` and double any internal `quote` char.
4. An empty field is emitted bare (as nothing) unless quoting is otherwise required.

## Round-trip guarantee

For any `rows`, `parse(dump(rows)) == rows` must hold (for non-empty `rows` whose fields
are strings), including fields containing delimiters, quotes, and embedded newlines.

## Configurability

Both functions must honor a non-default `delimiter` and `quote`, e.g. `parse(text, ';', "'")`
and `dump(rows, '\t', '"')` must use those characters for separation/quoting/escaping.
