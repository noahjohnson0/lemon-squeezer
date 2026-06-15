Write `expr.py` exporting a single function:

```python
def evaluate(s: str) -> float:
    """Evaluate an arithmetic expression and return the result as a float."""
```

Implement a real parser (precedence-climbing / Pratt, or recursive descent).
A naive left-to-right scan will fail the precedence and associativity cases.
Do NOT use `eval`, `exec`, `compile`, `ast.literal_eval`, or any expression
parser from the standard library or third-party packages. Tokenize and parse
the string yourself.

## Grammar and operators

Support these binary operators with standard math precedence and
left-associativity within a precedence level:

- `+` and `-` (addition, subtraction) - lowest precedence
- `*`, `/`, `%` (multiply, true-division, modulo) - higher precedence
- unary minus (e.g. `-5`, `-(2+3)`, `--3`, `2 * -3`) - binds tighter than the
  binary operators
- parentheses `( ... )` for grouping, arbitrarily nested

Precedence, highest to lowest: parentheses, unary minus, (`*` `/` `%`),
(`+` `-`).

## Number formats

Accept integer and floating-point literals, including:

- plain integers: `42`
- decimals: `3.14`, `.5`, `2.`
- scientific notation: `1e3`, `2.5E-2`, `1.2e+4`

`evaluate` always returns a Python `float`.

## Semantics (must match exactly)

- `/` is true division (float division), never integer/floor division.
- `%` follows Python's modulo semantics, including for negative and
  floating-point operands (e.g. `-7 % 3 == 2`, `5.5 % 2 == 1.5`).
- Left-associativity: `10 - 3 - 2 == 5`, `100 / 5 / 2 == 10`,
  `2 ** anything is NOT supported` (no exponent operator).
- Whitespace (spaces and tabs) between tokens is insignificant and may be
  absent entirely: `1+2*3` and ` 1 + 2 * 3 ` both evaluate to `7.0`.
- Precedence: `2 + 3 * 4 == 14`, `(2 + 3) * 4 == 20`, `2 * 3 + 4 == 10`.
- Unary minus composes: `-2 + 3 == 1`, `-(2 + 3) == -5`, `--5 == 5`,
  `2 - -3 == 5`, `-3 * -4 == 12`.

## Error handling (must raise an exception)

`evaluate` MUST raise an exception (any Exception subclass - `ValueError`,
`ZeroDivisionError`, `SyntaxError`, etc. all acceptable) on malformed input.
It must NOT return a wrong number or `None` and must NOT hang. Cases:

- empty or whitespace-only input: `""`, `"   "`
- unbalanced parentheses: `"(1 + 2"`, `"1 + 2)"`, `"(()"`
- empty parentheses: `"()"`, `"3 * ()"`
- a trailing or leading binary operator: `"1 +"`, `"* 3"`, `"1 + * 2"`
- two numbers with no operator between them: `"1 2"`, `"3 (4)"`
- division by zero: `"1 / 0"`, `"5 % 0"` (these may raise
  `ZeroDivisionError` - that counts as raising)
- garbage characters: `"1 $ 2"`, `"abc"`

## Performance

The parser must run in time linear in the length of the input. It must handle
both a long flat expression (thousands of `+`/`*` terms) and a deeply nested
parenthesized expression (thousands of nested parens) quickly - well under a
couple of seconds each. A quadratic or exponential parser will time out.

Create only `expr.py`. Don't run it.
