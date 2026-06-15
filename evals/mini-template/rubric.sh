#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
declare -A seen

# Sanitize notes so the emitted JSON stays valid: drop backslashes and turn
# double-quotes into single-quotes (both break the hand-rolled JSON below).
sanitize() {
  local s="$1"
  s="${s//\\/}"
  s="${s//\"/\'}"
  s="${s//$'\n'/ }"
  s="${s//$'\t'/ }"
  printf '%s' "$s"
}
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  note="$(sanitize "$note")"
  seen["$n"]=1
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

# Portable timeout (macOS=gtimeout, Linux=timeout). Used for both probes.
TO="$(command -v gtimeout || command -v timeout)"
run_to() { if [[ -n "$TO" ]]; then "$TO" "$@"; else shift; "$@"; fi; }

# ---------------------------------------------------------------------------
# Declared check inventory. EVERY name here is ALWAYS scored exactly once, so
# the denominator (sum of weights) is constant regardless of how broken the
# submission is. Behavioral checks are emitted by the python probe; anything
# the probe fails to emit is filled in as a 0 by the safety net below.
#
# Weighting puts most of the mass on the HARD discriminators (escaping, raw,
# nesting, error handling, performance), not on file-exists / happy-path.
# ---------------------------------------------------------------------------

# weight 3 - easy / happy path (a naive impl is expected to pass most of these)
EASY=(var_basic var_ws each_basic each_index if_true if_false missing_empty)
# weight 7 - hard edge cases (the discriminators)
HARD=(escape_all escape_no_double escape_amp_first raw_unescaped \
      else_branch dotted_path index_path none_empty bool_render \
      nest_each_in_if nest_if_in_each nest_each_in_each outer_in_loop \
      err_unclosed_if err_stray_close err_mismatch missing_each_noop \
      literal_html_kept)
EW=3
HW=7
PERFW=14  # performance bound carries real weight

T="$WS/template.py"
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:template.py" "$file_ok" 4

compiles_ok=0
if [[ "$file_ok" == "1" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && compiles_ok=1
fi
add "compiles" "$compiles_ok" 4

# ---------------------------------------------------------------------------
# Behavioral probe. The python block NEVER sys.exit()s on import error and
# NEVER lets one failing case abort the rest: chk() ALWAYS prints exactly one
# line per declared check, and an "imports" line is always emitted.
# ---------------------------------------------------------------------------
RES=$(cd "$WS" && run_to 15 python3 - <<'PY' 2>/tmp/mt_pyerr_$$
import sys

ok = True
try:
    from template import render
except Exception as e:
    print("IMPORT_ERR", repr(e)[:80], file=sys.stderr)
    ok = False

def emit(name, passed, note=""):
    note = str(note).replace("\\", "").replace('"', "'").replace("\n", " ").replace("\t", " ")
    print(name, 1 if passed else 0, note)

def chk(name, fn):
    if not ok:
        emit(name, 0, "import failed")
        return
    try:
        emit(name, 1 if fn() else 0)
    except Exception as ex:
        emit(name, 0, repr(ex)[:50])

emit("imports", ok, "" if ok else "could not import render")

def eq(got, want):
    return got == want

def raises_value_error(src, ctx):
    try:
        render(src, ctx)
    except ValueError:
        return True
    except Exception:
        # Wrong exception type is NOT acceptable per the spec.
        return False
    return False

# --- easy / happy path -----------------------------------------------------
chk("var_basic",   lambda: eq(render("Hi {{name}}!", {"name": "Ada"}), "Hi Ada!"))
chk("var_ws",      lambda: eq(render("[{{  name  }}]", {"name": "x"}), "[x]"))
chk("each_basic",  lambda: eq(render("{{#each xs}}<{{this}}>{{/each}}",
                                     {"xs": ["a", "b", "c"]}), "<a><b><c>"))
chk("each_index",  lambda: eq(render("{{#each xs}}{{@index}}={{this}};{{/each}}",
                                     {"xs": ["a", "b"]}), "0=a;1=b;"))
chk("if_true",     lambda: eq(render("{{#if ok}}YES{{/if}}", {"ok": True}), "YES"))
chk("if_false",    lambda: eq(render("{{#if ok}}YES{{/if}}", {"ok": False}), ""))
chk("missing_empty", lambda: eq(render("a{{nope}}b", {}), "ab"))

# --- hard edge cases (discriminators) --------------------------------------

# Escape exactly the five chars, & first, no double-escaping.
chk("escape_all", lambda: eq(
    render("{{v}}", {"v": "<b>&\"'"}),
    "&lt;b&gt;&amp;&quot;&#39;"))
chk("escape_no_double", lambda: eq(
    render("{{v}}", {"v": "a & b"}), "a &amp; b"))
# If & were escaped last, "<" -> "&lt;" -> "&amp;lt;". Catch that ordering bug.
chk("escape_amp_first", lambda: eq(
    render("{{v}}", {"v": "<&"}), "&lt;&amp;"))
# Triple braces => raw, unescaped.
chk("raw_unescaped", lambda: eq(
    render("{{{v}}}", {"v": "<i>&</i>"}), "<i>&</i>"))

# {{else}} branch.
chk("else_branch", lambda: eq(
    render("{{#if ok}}Y{{else}}N{{/if}}", {"ok": False}), "N"))

# Dotted nested path and integer list-index path.
chk("dotted_path", lambda: eq(
    render("{{a.b.c}}", {"a": {"b": {"c": "deep"}}}), "deep"))
chk("index_path", lambda: eq(
    render("{{items.1}}", {"items": ["zero", "one", "two"]}), "one"))

# None renders as "", bools render as Python str().
chk("none_empty", lambda: eq(render("[{{x}}]", {"x": None}), "[]"))
chk("bool_render", lambda: eq(render("{{x}}", {"x": True}), "True"))

# --- nesting (the central hard requirement) --------------------------------
chk("nest_each_in_if", lambda: eq(
    render("{{#if show}}{{#each xs}}[{{this}}]{{/each}}{{/if}}",
           {"show": True, "xs": ["a", "b"]}), "[a][b]"))
chk("nest_if_in_each", lambda: eq(
    render("{{#each xs}}{{#if this}}T{{else}}F{{/if}}{{/each}}",
           {"xs": [1, 0, 2]}), "TFT"))
chk("nest_each_in_each", lambda: eq(
    render("{{#each rows}}{{#each this}}{{this}}{{/each}}|{{/each}}",
           {"rows": [["a", "b"], ["c"]]}), "ab|c|"))
# Outer-scope context vars stay visible inside loops.
chk("outer_in_loop", lambda: eq(
    render("{{#each xs}}{{label}}:{{this}} {{/each}}",
           {"label": "n", "xs": [1, 2]}), "n:1 n:2 "))

# --- error handling: must raise ValueError specifically --------------------
chk("err_unclosed_if", lambda: raises_value_error("{{#if x}}abc", {"x": 1}))
chk("err_stray_close", lambda: raises_value_error("abc{{/if}}", {}))
chk("err_mismatch", lambda: raises_value_error("{{#if x}}a{{/each}}", {"x": 1}))

# Iterating a missing path or non-list renders the body zero times (no error).
chk("missing_each_noop", lambda: eq(
    render("[{{#each nope}}{{this}}{{/each}}]", {}), "[]"))

# Literal HTML in the template text is copied verbatim (not escaped).
chk("literal_html_kept", lambda: eq(
    render("<div>{{v}}</div>", {"v": "x"}), "<div>x</div>"))
PY
)
PYRC=$?
PYERR="$(cat /tmp/mt_pyerr_$$ 2>/dev/null)"; rm -f /tmp/mt_pyerr_$$
{ echo "=== probe stdout ==="; echo "$RES"; echo "=== probe stderr ==="; echo "$PYERR"; echo "=== probe rc=$PYRC ==="; } >&2

IMPORTS_PASS=0
IMPORTS_NOTE="probe did not emit imports line"

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  [[ "$name" == "IMPORT_ERR" ]] && continue
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  if [[ "$name" == "imports" ]]; then
    IMPORTS_PASS="$pass"; IMPORTS_NOTE="$note"; continue
  fi
  # Weight by membership in EASY vs HARD; ignore unexpected names.
  is_easy=0; for n in "${EASY[@]}"; do [[ "$n" == "$name" ]] && is_easy=1 && break; done
  is_hard=0; for n in "${HARD[@]}"; do [[ "$n" == "$name" ]] && is_hard=1 && break; done
  if [[ "$is_easy" == "1" ]]; then add "$name" "$pass" "$EW" "$note"
  elif [[ "$is_hard" == "1" ]]; then add "$name" "$pass" "$HW" "$note"
  fi
done < <(printf '%s\n' "$RES")

add "imports" "$IMPORTS_PASS" 5 "$IMPORTS_NOTE"

# Safety net: any declared behavioral check the probe failed to emit (crash /
# timeout / kill) is scored 0 so the denominator stays constant.
for n in "${EASY[@]}"; do [[ -n "${seen[$n]:-}" ]] || add "$n" 0 "$EW" "missing from probe output"; done
for n in "${HARD[@]}"; do [[ -n "${seen[$n]:-}" ]] || add "$n" 0 "$HW" "missing from probe output"; done

# ---------------------------------------------------------------------------
# PERFORMANCE check (separate, tightly-bounded probe). A correct linear engine
# that accumulates pieces and "".join()s them expands a ~5.6M-char output in
# about a second; an engine that builds output by per-element string
# concatenation or re-scans the body/output per element (re.sub, repeated
# .replace) takes many times longer and is killed -> rc!=0 -> perf fails.
# Deterministic: fixed size, no clock read, no randomness. The probe also
# verifies the output, so timing out OR producing wrong output both fail; a
# perf-only no-op cannot pass.
# ---------------------------------------------------------------------------
perf_pass=0; perf_note="not run"
if [[ "$compiles_ok" == "1" && "$IMPORTS_PASS" == "1" ]]; then
  if run_to 3 python3 - "$WS" >/tmp/mt_perf_$$ 2>/tmp/mt_perferr_$$ <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
from template import render

# Each iteration emits a fixed 13-char row; 800k rows => ~5.6M chars of output.
# A correct linear engine does this in ~1s here; quadratic concat blows the 3s
# budget by a wide margin.
N = 800000
src = "{{#each xs}}<row>{{@index}}</row>{{/each}}"
ctx = {"xs": list(range(N))}
out = render(src, ctx)
# Correctness sanity so a perf-only no-op can't pass: spot-check boundaries.
assert out.startswith("<row>0</row><row>1</row>"), "bad head"
assert out.endswith("<row>%d</row>" % (N - 1)), "bad tail"
assert out.count("<row>") == N, "wrong row count"
print("PERF_OK")
PY
  then
    if grep -q "PERF_OK" /tmp/mt_perf_$$ 2>/dev/null; then
      perf_pass=1; perf_note="linear render within budget"
    else
      perf_note="probe did not confirm output"
    fi
  else
    perf_note="timed out or errored (likely quadratic)"
  fi
  { echo "=== perf stdout ==="; cat /tmp/mt_perf_$$ 2>/dev/null; echo "=== perf stderr ==="; cat /tmp/mt_perferr_$$ 2>/dev/null; } >&2
  rm -f /tmp/mt_perf_$$ /tmp/mt_perferr_$$
else
  perf_note="no importable solution"
fi
add "perf_linear" "$perf_pass" "$PERFW" "$perf_note"

# ---------------------------------------------------------------------------
# Static anti-cheat: must implement the engine, not delegate to a templating
# library. Only credited when the file exists AND imports (so an empty stub
# can't earn this absence-check for free).
# ---------------------------------------------------------------------------
if [[ "$file_ok" == "1" && "$IMPORTS_PASS" == "1" ]]; then
  if grep -qiE "import[[:space:]]+(jinja2|mako|django|chameleon|genshi)|from[[:space:]]+(jinja2|mako|django)" "$T"; then
    add "no_template_lib" 0 6 "uses a third-party templating library"
  else
    add "no_template_lib" 1 6
  fi
else
  add "no_template_lib" 0 6 "no importable solution"
fi

# ---------------------------------------------------------------------------
# Emit the score JSON. THIS is the only thing on stdout.
# ---------------------------------------------------------------------------
total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in "${checks[@]+"${checks[@]}"}"; do
    IFS=$'\t' read -r name pass weight note <<<"$c"
    total=$((total+weight)); [[ "$pass" == "1" ]] && gained=$((gained+weight))
    [[ $first -eq 0 ]] && printf ',\n'
    printf '    {"name":"%s","pass":%s,"weight":%s,"note":"%s"}' "$name" "$pass" "$weight" "$note"
    first=0
  done
  printf '\n  ],\n'
  pct=0; [[ $total -gt 0 ]] && pct=$(( (gained * 100) / total ))
  printf '  "gained": %s,\n  "total": %s,\n  "score_pct": %s\n}\n' "$gained" "$total" "$pct"
}
