#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks

# Sanitize notes so the emitted JSON stays valid: strip backslashes and turn
# double-quotes into single-quotes (both break the hand-rolled JSON below).
sanitize() {
  local s="$1"
  s="${s//\\/ }"
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

# Portable timeout: prefer gtimeout (coreutils on macOS), fall back to timeout.
TO="$(command -v gtimeout || command -v timeout || true)"
run_to() {  # run_to <secs> <cmd...>
  local secs="$1"; shift
  if [[ -n "$TO" ]]; then "$TO" "$secs" "$@"; else "$@"; fi
}

T="$WS/csvdialect.py"

# --- static checks (small weights; real points are behavioral) ---
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:csvdialect.py" "$file_ok" 3

compile_ok=0
if [[ "$file_ok" == "1" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && compile_ok=1
fi
add "compiles" "$compile_ok" 3

# Anti-cheat: must NOT use the stdlib csv module. Only credited for a real,
# importable file so an empty stub can't earn free points for an absence-check.
no_csv=0
if [[ "$file_ok" == "1" ]]; then
  if grep -qE "^[[:space:]]*import[[:space:]]+csv\b|^[[:space:]]*from[[:space:]]+csv[[:space:]]+import" "$T"; then
    no_csv=0
  else
    no_csv=1
  fi
fi
# gate on import success below (recompute after we know import status)

# --- behavioral + perf checks ---
# The python block ALWAYS prints exactly one line per declared check via emit(),
# whether import works or not, so the denominator is CONSTANT for every
# submission (empty stub, import-error, partial, correct). All diagnostics go to
# stderr; only "<name> <0|1> [note]" lines go to stdout.
RES=$(cd "$WS" && run_to 15 python3 - <<'PY' 2>>/dev/null
import sys, time

ok = True
try:
    from csvdialect import parse, dump
except Exception as e:
    print("IMPORT_ERR", repr(e)[:80], file=sys.stderr)
    ok = False

def emit(name, passed, note=""):
    note = str(note).replace("\\", " ").replace('"', "'").replace("\n", " ").replace("\t", " ")
    print(name, 1 if passed else 0, note)

def chk(name, fn):
    if not ok:
        emit(name, 0, "import_failed")
        return
    try:
        emit(name, 1 if fn() else 0)
    except Exception as ex:
        emit(name, 0, repr(ex)[:50])

emit("imports", ok, "" if ok else "could not import parse/dump")

# ---------- parse: happy path ----------
chk("p_basic",      lambda: parse("a,b,c") == [["a", "b", "c"]])
chk("p_two_rows",   lambda: parse("a,b\nc,d") == [["a", "b"], ["c", "d"]])

# ---------- parse: trailing newline / blank lines ----------
chk("p_trailing_nl",   lambda: parse("a,b\n") == [["a", "b"]])
chk("p_empty_input",   lambda: parse("") == [])
chk("p_blank_between",  lambda: parse("a\n\nb") == [["a"], [""], ["b"]])

# ---------- parse: empty fields ----------
chk("p_empty_mid",     lambda: parse("a,,c") == [["a", "", "c"]])
chk("p_two_empty",     lambda: parse(",") == [["", ""]])
chk("p_quoted_empty",  lambda: parse('""') == [[""]])

# ---------- parse: spaces are significant ----------
chk("p_spaces",        lambda: parse(" a , b ") == [[" a ", " b "]])

# ---------- parse: quoting ----------
chk("p_quoted_delim",  lambda: parse('"a,b",c') == [["a,b", "c"]])
chk("p_escaped_quote", lambda: parse('"she said ""hi"""') == [['she said "hi"']])
chk("p_embedded_nl",   lambda: parse('"line1\nline2",x') == [["line1\nline2", "x"]])
chk("p_quoted_then_row", lambda: parse('"a\nb"\nc') == [["a\nb"], ["c"]])

# ---------- parse: line-ending normalization ----------
chk("p_crlf",          lambda: parse("a,b\r\nc,d") == [["a", "b"], ["c", "d"]])
chk("p_bare_cr",       lambda: parse("a,b\rc,d") == [["a", "b"], ["c", "d"]])
chk("p_cr_in_quotes",  lambda: parse('"a\r\nb",c') == [["a\r\nb", "c"]])

# ---------- parse: configurable delimiter / quote ----------
chk("p_semicolon",     lambda: parse("a;b;c", delimiter=";") == [["a", "b", "c"]])
chk("p_alt_quote",     lambda: parse("'a;b';c", delimiter=";", quote="'") == [["a;b", "c"]])
chk("p_alt_escape",    lambda: parse("'a''b'", quote="'") == [["a'b"]])

# ---------- dump: minimal quoting (must NOT quote everything) ----------
chk("d_basic",         lambda: dump([["a", "b", "c"]]) == "a,b,c\n")
chk("d_empty_rows",    lambda: dump([]) == "")
chk("d_empty_field",   lambda: dump([["a", "", "c"]]) == "a,,c\n")
chk("d_quote_delim",   lambda: dump([["a,b", "c"]]) == '"a,b",c\n')
chk("d_escape_quote",  lambda: dump([['a"b']]) == '"a""b"\n')
chk("d_quote_nl",      lambda: dump([["a\nb", "c"]]) == '"a\nb",c\n')
chk("d_no_overquote",  lambda: dump([["plain", "text"]]) == "plain,text\n")
chk("d_alt_delim",     lambda: dump([["a\tb"]], delimiter="\t") == '"a\tb"\n')

# ---------- round-trip ----------
def round_trip():
    rows = [
        ["a", "b,c", 'd"e'],
        ["multi\nline", "", "tab\tend"],
        ['"', ",", "\n"],
        ["plain", "trailing ", " leading"],
    ]
    return parse(dump(rows)) == rows
chk("round_trip", round_trip)

def round_trip_alt():
    rows = [["x;y", "z'w"], ["a", "b\nc"]]
    s = dump(rows, delimiter=";", quote="'")
    return parse(s, delimiter=";", quote="'") == rows
chk("round_trip_alt", round_trip_alt)

# ---------- performance + correctness at scale ----------
# One record with N fields; every 5th field is quoted and contains an embedded
# delimiter AND a newline. A correct LINEAR parser returns N fields with the
# right content in well under the timeout. A quadratic parser (rebuilding the
# remaining text each char) times out and the whole block is killed -> this
# line is never emitted and the bash side scores it 0. A naive split-on-delim
# / split-on-newline parser returns the WRONG field count/content and fails.
def perf_big():
    N = 200000
    parts = []
    for i in range(N):
        if i % 5 == 0:
            parts.append('"x,%d\ny"' % i)
        else:
            parts.append("f%d" % i)
    text = ",".join(parts)
    t0 = time.time()
    rows = parse(text)
    dt = time.time() - t0
    if len(rows) != 1:
        return False
    rec = rows[0]
    if len(rec) != N:
        return False
    # spot-check a quoted and a plain field
    if rec[0] != "x,0\ny":
        return False
    if rec[1] != "f1":
        return False
    if rec[5] != "x,5\ny":
        return False
    if rec[N - 1] != ("x,%d\ny" % (N - 1) if (N - 1) % 5 == 0 else "f%d" % (N - 1)):
        return False
    return dt < 8.0
chk("perf_big", perf_big)

# Dump-at-scale correctness + linearity. Each of N cells contains an internal
# quote, so a CORRECT dump must quote-wrap AND double the internal quote
# ("a""b") for every cell; a naive dump that forgets to escape (or only quotes
# on the delimiter) produces the wrong string and fails deterministically,
# independent of machine speed. The generous time bound also trips a genuinely
# pathological O(n^2) implementation without false-failing a linear one.
def perf_dump():
    N = 100000
    rows = [['a"b' for _ in range(N)]]
    t0 = time.time()
    s = dump(rows)
    dt = time.time() - t0
    if not s.endswith("\n"):
        return False
    # each cell must serialize as the escaped, quoted form "a""b"
    if s.count('"a""b"') != N:
        return False
    # plain quote chars only appear as part of that escaped form: 4 per cell
    if s.count('"') != 4 * N:
        return False
    return dt < 10.0
chk("perf_dump", perf_dump)
PY
)
echo "$RES" >&2

# Derive import success from the emitted "imports" line so the static anti-cheat
# check is only credited for a real, importable solution.
import_ok=0
if printf '%s\n' "$RES" | grep -qE '^imports[[:space:]]+1'; then
  import_ok=1
fi
if [[ "$import_ok" == "1" && "$file_ok" == "1" && "$no_csv" == "1" ]]; then
  add "no_stdlib_csv" 1 6
else
  if [[ "$import_ok" == "1" && "$file_ok" == "1" ]]; then
    add "no_stdlib_csv" 0 6 "uses stdlib csv module"
  else
    add "no_stdlib_csv" 0 6 "no importable solution"
  fi
fi

# Fold each emitted behavioral line in. Weights are declared per-name below so a
# missing line (timeout/crash) is still added as 0 -> constant denominator.
declare -A SEEN
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "$line" == IMPORT_ERR* ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  SEEN["$name"]="$pass"$'\t'"$note"
done < <(printf '%s\n' "$RES")

emit_chk() {  # emit_chk <name> <weight>
  local name="$1" weight="$2"
  if [[ -n "${SEEN[$name]+x}" ]]; then
    local pass note
    IFS=$'\t' read -r pass note <<<"${SEEN[$name]}"
    add "$name" "$pass" "$weight" "$note"
  else
    add "$name" 0 "$weight" "not emitted (crash/timeout)"
  fi
}

# Weighting: import gate small; happy-path small; EDGE CASES + PERF carry the
# load. Total behavioral weight dominates static/anti-cheat (12) so a naive
# happy-path solution can't clear a passing bar.
emit_chk "imports" 4

# happy path (low weight)
emit_chk "p_basic" 2
emit_chk "p_two_rows" 2
emit_chk "d_basic" 2
emit_chk "d_empty_rows" 2

# edge cases (high weight)
emit_chk "p_trailing_nl"     6
emit_chk "p_empty_input"     5
emit_chk "p_blank_between"   7
emit_chk "p_empty_mid"       4
emit_chk "p_two_empty"       5
emit_chk "p_quoted_empty"    6
emit_chk "p_spaces"          4
emit_chk "p_quoted_delim"    7
emit_chk "p_escaped_quote"   9
emit_chk "p_embedded_nl"     9
emit_chk "p_quoted_then_row" 8
emit_chk "p_crlf"            6
emit_chk "p_bare_cr"         7
emit_chk "p_cr_in_quotes"    6
emit_chk "p_semicolon"       4
emit_chk "p_alt_quote"       7
emit_chk "p_alt_escape"      7

emit_chk "d_empty_field"     4
emit_chk "d_quote_delim"     7
emit_chk "d_escape_quote"    8
emit_chk "d_quote_nl"        7
emit_chk "d_no_overquote"    8
emit_chk "d_alt_delim"       6

emit_chk "round_trip"        10
emit_chk "round_trip_alt"    8

# performance (high weight)
emit_chk "perf_big"          12
emit_chk "perf_dump"         10

# --- emit final JSON (stdout) ; everything above went to stderr ---
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
