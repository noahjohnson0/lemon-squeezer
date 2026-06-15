#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks

# Sanitize notes so the emitted JSON stays valid: strip backslashes and turn
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
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

# Portable timeout: prefer gtimeout (mac coreutils), fall back to timeout (linux).
TO="$(command -v gtimeout || command -v timeout || true)"

T="$WS/config.py"

# --- static checks (small weight: a stub that merely exists/compiles must not
# clear a passing score on static credit alone) ---
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:config.py" "$file_ok" 3

compile_ok=0
if [[ "$file_ok" == "1" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && compile_ok=1
fi
add "compiles" "$compile_ok" 3

# Static anti-cheat: must not lean on stdlib config/serialization parsers.
# Only credited when the file exists (a missing file gets 0, not free credit).
if [[ "$file_ok" == "1" ]]; then
  if grep -qE "import[[:space:]]+(configparser|tomllib|toml|json)\b|from[[:space:]]+(configparser|tomllib|toml|json|ast)[[:space:]]+import|ast\.literal_eval" "$T"; then
    add "no_stdlib_parser" 0 6 "uses configparser/toml/json/ast"
  else
    add "no_stdlib_parser" 1 6
  fi
else
  add "no_stdlib_parser" 0 6 "no file"
fi

# --- behavioral checks ---
# The python heredoc ALWAYS prints exactly one line per declared check via chk(),
# whether the import works or not, so the denominator is CONSTANT for every
# submission (empty stub, import-error, partial, correct). All diagnostics go to
# stderr; only "<name> <0|1> [note]" lines reach stdout.
RES=$(WS="$WS" ${TO:+$TO 20} python3 - <<'PY' 2>/dev/null
import sys, os, math
ws = os.environ["WS"]
sys.path.insert(0, ws)

ok = True
ConfigError = None
loads = None
try:
    import config as _cfg
    loads = _cfg.loads
    ConfigError = getattr(_cfg, "ConfigError", None)
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


emit("imports", ok, "" if ok else "could not import config.loads")


# ConfigError must be a defined ValueError subclass.
def has_configerror():
    return (ConfigError is not None and isinstance(ConfigError, type)
            and issubclass(ConfigError, ValueError))
chk("configerror_defined", has_configerror)


def eq(text, expected):
    return loads(text) == expected


def raises(text):
    # Must raise the declared ConfigError (a ValueError subclass), not some
    # incidental KeyError/IndexError. If ConfigError is missing we still accept
    # ValueError so a correct-but-unexported-name impl isn't double-penalized.
    exc = ConfigError if (ConfigError is not None) else ValueError
    try:
        loads(text)
    except exc:
        return True
    except Exception:
        return False
    return False


# ---------- happy path (a naive solution should also pass most of these) ----------
chk("h_int",     lambda: eq("a = 1", {"a": 1}))
chk("h_float",   lambda: eq("a = 3.14", {"a": 3.14}))
chk("h_bool",    lambda: eq("a = true", {"a": True}))
chk("h_string",  lambda: eq("a = hello", {"a": "hello"}))
chk("h_section", lambda: eq("[s]\nk = 1", {"s": {"k": 1}}))
chk("h_blank_comment", lambda: eq("x=1\n# c\n; c2\n\ny=2", {"x": 1, "y": 2}))
chk("h_two_sections", lambda: eq("[s]\na=1\n[t]\na=2", {"s": {"a": 1}, "t": {"a": 2}}))


# ---------- type coercion edge cases ----------
chk("c_neg_int",  lambda: eq("a = -7", {"a": -7}))
chk("c_plus_int", lambda: eq("a = +0", {"a": 0}))
# quoted-numeric stays a string
chk("c_quoted_num", lambda: eq('a = "42"', {"a": "42"}) and isinstance(loads('a = "42"')["a"], str))
# leading-zero multi-digit stays a string
chk("c_leading_zero", lambda: eq("a = 007", {"a": "007"}))
# underscore numerics are strings
chk("c_underscore", lambda: eq("a = 1_000", {"a": "1_000"}))
# .5 and 2. are floats
chk("c_dot_float", lambda: eq("a = .5", {"a": 0.5}) and eq("a = 2.", {"a": 2.0}))
# scientific notation
chk("c_sci", lambda: eq("a = 6.02e23", {"a": 6.02e23}) and eq("a = -1.5E-3", {"a": -1.5e-3}))
# inf/nan stay strings (must not become float)
chk("c_inf_nan", lambda: eq("a = inf", {"a": "inf"}) and eq("a = nan", {"a": "nan"}))
# case-insensitive bool
chk("c_bool_case", lambda: eq("a = FALSE", {"a": False}) and eq("a = True", {"a": True}))
# bool stays a real bool, not int/str
chk("c_bool_type", lambda: loads("a = true")["a"] is True)
# empty value is the empty string
chk("c_empty_value", lambda: eq("k =", {"k": ""}))


# ---------- comment vs quote (THE discriminator) ----------
chk("q_hash_in_dquote",  lambda: eq('a = "a # b"', {"a": "a # b"}))
chk("q_semi_in_squote",  lambda: eq("a = 'a;b#c'", {"a": "a;b#c"}))
chk("q_trailing_after_quote", lambda: eq('a = "x" # c', {"a": "x"}))
chk("q_inline_hash",     lambda: eq("a = value # trailing", {"a": "value"}))
chk("q_inline_semi",     lambda: eq("a = ab ; cd", {"a": "ab"}))
chk("q_no_space_hash",   lambda: eq("a = a#b", {"a": "a"}))
chk("q_eq_in_quote",     lambda: eq('a = "k = v"', {"a": "k = v"}))
chk("q_section_comment", lambda: eq("[s] # c\nk=1", {"s": {"k": 1}}))


# ---------- quoted string escapes ----------
chk("e_dquote_escapes", lambda: eq('a = "x\\ty\\nz"', {"a": "x\ty\nz"}))
chk("e_escaped_quote",  lambda: eq('a = "say \\"hi\\""', {"a": 'say "hi"'}))
chk("e_squote_raw",     lambda: eq("a = 'a\\nb'", {"a": "a\\nb"}))
chk("e_dquote_backslash", lambda: eq('a = "c:\\\\tmp"', {"a": "c:\\tmp"}))


# ---------- nested / dotted sections ----------
chk("n_dotted",      lambda: eq("[a.b.c]\nx=1", {"a": {"b": {"c": {"x": 1}}}}))
chk("n_ws_in_dots",  lambda: eq("[ a . b ]\nx=1", {"a": {"b": {"x": 1}}}))
chk("n_empty_sect",  lambda: eq("[a.b]", {"a": {"b": {}}}))
chk("n_top_then_sect", lambda: eq("top=1\n[s]\nk=2", {"top": 1, "s": {"k": 2}}))
chk("n_same_key_diff_sect", lambda: eq("[s]\na=1\n[t]\na=2", {"s": {"a": 1}, "t": {"a": 2}}))


# ---------- line continuations ----------
chk("k_continue_value", lambda: eq("a = foo\\\nbar", {"a": "foobar"}))
chk("k_continue_multi", lambda: eq("a = 1\\\n2\\\n3", {"a": 123}))
# continuation joins with NO inserted space
chk("k_continue_nospace", lambda: eq("a = ab\\\ncd", {"a": "abcd"}))


# ---------- malformed -> ConfigError ----------
chk("m_empty_section",     lambda: raises("[]"))
chk("m_empty_component",   lambda: raises("[a..b]") and raises("[a.]") and raises("[.b]"))
chk("m_section_junk",      lambda: raises("[a] x"))
chk("m_dup_section",       lambda: raises("[a.b]\n[a.b]"))
chk("m_section_scalar_collision", lambda: raises("x=1\n[x.y]"))
chk("m_no_eq",             lambda: raises("noeq"))
chk("m_empty_key",         lambda: raises("= 5"))
chk("m_dup_key",           lambda: raises("[s]\nk=1\nk=2"))
chk("m_unterminated_dquote", lambda: raises('a = "x'))
chk("m_unterminated_squote", lambda: raises("a = 'x"))
chk("m_unknown_escape",    lambda: raises('a = "a\\q"'))
chk("m_trailing_after_quote_junk", lambda: raises('a = "x" y'))
chk("m_dangling_continuation", lambda: raises("a = \\"))
chk("m_dangling_escape",   lambda: raises('a = "ab\\'))


# ---------- valid-not-error guards (a too-eager error-raiser fails these) ----------
chk("v_hash_not_error",  lambda: eq("a = a#b", {"a": "a"}))
chk("v_dup_diff_sect_ok", lambda: eq("[s]\nk=1\n[t]\nk=2", {"s": {"k": 1}, "t": {"k": 2}}))
chk("v_nested_no_parent", lambda: eq("[a.b]\nx=1", {"a": {"b": {"x": 1}}}))


# ---------- performance: O(n) required ----------
# A value containing a very long run of comment-like chars inside quotes, plus
# tens of thousands of lines. A quadratic scanner (per-char re-slice / re-scan
# of the remaining string) blows the 20s timeout; a linear one is well under 1s.
def perf():
    big_val = '"' + ("# ; = a" * 40000) + '"'   # ~280k chars, all inside quotes
    text = "big = " + big_val + "\n"
    text += "\n".join("k%d = %d # c%d" % (i, i, i) for i in range(40000))
    import time
    t0 = time.time()
    d = loads(text)
    dt = time.time() - t0
    if dt > 8.0:
        return False
    if not isinstance(d["big"], str):
        return False
    # the long comment-like run must survive intact inside the quotes
    if d["big"] != ("# ; = a" * 40000):
        return False
    return d["k0"] == 0 and d["k39999"] == 39999
chk("perf_linear", perf)
PY
)
echo "$RES" >&2

# Build name -> "pass<TAB>note" map. chk() guarantees one line per declared
# check; if the interpreter died mid-stream the trailing declared checks are
# padded to 0 below so the denominator stays CONSTANT.
declare -A SEEN
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "$line" == IMPORT_ERR* ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  SEEN["$name"]="$pass"$'\t'"$note"
done < <(printf '%s\n' "$RES")

# Declared behavioral checks + weights. Most weight is on the HARD groups
# (comment-vs-quote, escapes, malformed, perf); happy-path is cheap so a naive
# happy-path-only solution lands in the middle, not near passing.
emit_chk() {
  local name="$1" weight="$2"
  if [[ -n "${SEEN[$name]+x}" ]]; then
    local pass note
    IFS=$'\t' read -r pass note <<<"${SEEN[$name]}"
    add "$name" "$pass" "$weight" "$note"
  else
    add "$name" 0 "$weight" "not emitted"
  fi
}

# infra
emit_chk "imports" 4
emit_chk "configerror_defined" 4
# happy path (cheap)
for c in h_int h_float h_bool h_string h_section h_blank_comment h_two_sections; do
  emit_chk "$c" 2
done
# coercion edges (medium)
for c in c_neg_int c_plus_int c_quoted_num c_leading_zero c_underscore c_dot_float \
         c_sci c_inf_nan c_bool_case c_bool_type c_empty_value; do
  emit_chk "$c" 5
done
# comment-vs-quote (heavy: the discriminator)
for c in q_hash_in_dquote q_semi_in_squote q_trailing_after_quote q_inline_hash \
         q_inline_semi q_no_space_hash q_eq_in_quote q_section_comment; do
  emit_chk "$c" 7
done
# escapes (heavy)
for c in e_dquote_escapes e_escaped_quote e_squote_raw e_dquote_backslash; do
  emit_chk "$c" 7
done
# nested sections (medium)
for c in n_dotted n_ws_in_dots n_empty_sect n_top_then_sect n_same_key_diff_sect; do
  emit_chk "$c" 5
done
# continuations (heavy)
for c in k_continue_value k_continue_multi k_continue_nospace; do
  emit_chk "$c" 7
done
# malformed -> error (heavy)
for c in m_empty_section m_empty_component m_section_junk m_dup_section \
         m_section_scalar_collision m_no_eq m_empty_key m_dup_key \
         m_unterminated_dquote m_unterminated_squote m_unknown_escape \
         m_trailing_after_quote_junk m_dangling_continuation m_dangling_escape; do
  emit_chk "$c" 6
done
# valid-not-error guards (medium)
for c in v_hash_not_error v_dup_diff_sect_ok v_nested_no_parent; do
  emit_chk "$c" 5
done
# performance (heavy)
emit_chk "perf_linear" 12

# --- emit final JSON (stdout) ; everything else above went to stderr ---
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
