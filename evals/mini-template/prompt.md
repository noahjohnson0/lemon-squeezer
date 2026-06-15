Write `template.py` exporting a single function:

```python
def render(src: str, context: dict) -> str:
    """Render a string template `src` against `context` and return the result."""
```

Implement a small logic-ful template engine. Do NOT use jinja2, mako, django,
or any third-party templating library - implement the parsing and rendering
yourself with the standard library only.

## Syntax to support

### 1. Variable interpolation `{{ var }}`
- `{{name}}` looks up `context["name"]` and inserts its string form (`str(value)`).
- Whitespace inside the braces is ignored: `{{ name }}` == `{{name}}`.
- Dotted paths do nested lookups: `{{a.b.c}}` resolves
  `context["a"]["b"]["c"]`. A path segment may also index a list by integer:
  `{{items.0}}` is `context["items"][0]`.
- A missing variable (missing key, missing attribute, index out of range, or
  indexing into a non-container) renders as the EMPTY STRING `""`, never an
  error and never the literal text.
- A value of `None` renders as the empty string `""` (NOT the text "None").
- Boolean values render as `True` / `False` (Python `str()` form).

### 2. HTML escaping (default) and raw `{{{ raw }}}`
- `{{ var }}` HTML-escapes the value before inserting it. Escape exactly these
  five characters, in a way that does not double-escape:
  `&` -> `&amp;`, `<` -> `&lt;`, `>` -> `&gt;`, `"` -> `&quot;`, `'` -> `&#39;`.
  `&` MUST be escaped first so `<` does not become `&amp;lt;`.
- `{{{ var }}}` (triple braces) inserts the value WITHOUT escaping (raw HTML).
- Escaping applies to interpolated values only. Literal template text is copied
  through verbatim and is NOT escaped (a literal `<div>` in the template stays
  `<div>`).

### 3. Conditionals `{{#if cond}}...{{else}}...{{/if}}`
- `{{#if cond}}A{{/if}}` renders `A` iff `cond` is truthy. `{{else}}` is
  optional: `{{#if cond}}A{{else}}B{{/if}}` renders `B` when `cond` is falsy.
- `cond` is a dotted path resolved the same way as a variable.
- Truthiness is Python truthiness applied to the resolved value, EXCEPT a
  missing path is falsy (renders the else branch / nothing). So `0`, `""`,
  `[]`, `{}`, `False`, `None`, and missing are all falsy; non-empty values are
  truthy.

### 4. Loops `{{#each list}}...{{/each}}`
- Repeats the inner body once per element of the resolved list (or any
  iterable; a dict iterates its values is NOT required - only lists/tuples).
- Inside the body:
  - `{{this}}` is the current element. `{{{this}}}` is the unescaped element.
  - `{{@index}}` is the 0-based index of the current element.
  - dotted paths off the element work: if elements are dicts, `{{this.name}}`
    resolves `element["name"]`.
- Iterating a missing path or a non-list renders the body ZERO times (no error).
- An empty list renders the body zero times.

### 5. Nesting (REQUIRED, this is the hard part)
- Blocks nest arbitrarily: `{{#each}}` inside `{{#if}}` inside `{{#each}}`, etc.
  `{{/if}}` / `{{/each}}` must match the nearest matching opener (proper stack).
- Inside a nested `{{#each}}`, an inner `{{this}}` / `{{@index}}` refers to the
  INNER loop; outer-scope variables (plain `{{name}}` and dotted context paths)
  remain visible inside loops and conditionals.

### 6. Errors on malformed templates
- `render` MUST raise `ValueError` (not any other exception type, not return
  garbage) when the block structure is unbalanced, specifically:
  - an unclosed block: `{{#if x}}abc` (no `{{/if}}`),
  - a stray closer with no opener: `abc{{/if}}`,
  - a mismatched closer: `{{#if x}}...{{/each}}`.
- A well-formed template with unknown variables is NOT an error (see rule 1).

## Performance

- Rendering must be at worst linear in `len(src) + size(output)`. In
  particular, building the output by repeated `result = result + piece` string
  concatenation inside the loop/recursion is too slow: a template that expands
  to a few hundred thousand characters via `{{#each}}` over a large list MUST
  render in well under a second. Accumulate pieces in a list and `"".join(...)`,
  or use an equivalent linear strategy. A quadratic implementation will time
  out and fail the performance check.

## Examples

```python
render("Hi {{name}}!", {"name": "Ada"})                 # "Hi Ada!"
render("{{a.b}}", {"a": {"b": "deep"}})                  # "deep"
render("{{x}}", {"x": "<b>&\"'"})                        # "&lt;b&gt;&amp;&quot;&#39;"
render("{{{x}}}", {"x": "<b>"})                          # "<b>"
render("{{#if ok}}Y{{else}}N{{/if}}", {"ok": False})     # "N"
render("{{#each xs}}[{{@index}}:{{this}}]{{/each}}", {"xs": ["a","b"]})  # "[0:a][1:b]"
render("{{missing}}", {})                                # ""
render("{{#if x}}A", {"x": 1})                           # raises ValueError
```

Create only `template.py`. Don't run it.
