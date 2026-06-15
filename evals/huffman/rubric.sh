#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  # sanitize note: strip backslashes and replace double-quotes so the JSON
  # never breaks (see CLAUDE.md rubric gotcha #2).
  note="${note//\\/}"
  note="${note//\"/\'}"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/huffman.py"
file_ok=0
[[ -f "$T" ]] && file_ok=1
add "file:huffman.py" "$file_ok" 5

# compiles check - always emitted (0 if the file is missing).
compiles=0
if [[ "$file_ok" == "1" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && compiles=1
fi
add "compiles" "$compiles" 5

# Behavioral checks. The python block ALWAYS prints exactly one line per
# declared check via chk(), even on import failure or per-case exception, so
# the set of emitted check names (and therefore the denominator) is CONSTANT
# regardless of how broken the submission is. All diagnostics go to stderr.
RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>>/dev/stderr
import sys

ok = True
build_codes = encode = decode = None
try:
    from huffman import build_codes, encode, decode
except Exception as e:
    print("IMPORT_ERR", repr(e)[:120], file=sys.stderr)
    ok = False

# imports check reflects whether the required names are importable.
print("imports", 1 if ok else 0)


def chk(name, fn):
    if not ok:
        print(name, 0, "no_import")
        return
    try:
        print(name, 1 if fn() else 0)
    except Exception as ex:
        # sanitize note here too (no quotes/backslashes leak into JSON later).
        note = repr(ex)[:50].replace('"', "'").replace("\\", "")
        print(name, 0, "ERR", note)


TEXTS = ["a", "ab", "hello world", "AAAAABCD",
         "the quick brown fox jumps over the lazy dog",
         "mississippi", "abracadabra" * 5]


def make_cases(i, t):
    # Each behavioral aspect recomputes codes from scratch so one failing
    # primitive doesn't poison an unrelated dimension's check.
    def rt():
        c = build_codes(t)
        return decode(encode(t, c), c) == t

    def length():
        c = build_codes(t)
        e = encode(t, c)
        return len(e) == sum(len(c[ch]) for ch in t)

    def prefix():
        c = build_codes(t)
        if not c:
            return False
        # all codes valid non-empty bitstrings
        if not all(set(v) <= {"0", "1"} and len(v) > 0 for v in c.values()):
            return False
        vals = list(c.values())
        return all(not (a != b and a.startswith(b)) for a in vals for b in vals)

    chk(f"t{i}_rt", rt)
    chk(f"t{i}_len", length)
    chk(f"t{i}_prefix", prefix)


for i, t in enumerate(TEXTS, 1):
    make_cases(i, t)

# Empty handling - each emitted via chk so it can never abort the rest.
chk("empty_codes", lambda: build_codes("") == {})
chk("empty_encode", lambda: encode("", build_codes("")) == "")
chk("empty_decode", lambda: decode("", build_codes("")) == "")
PY
)
echo "RES>>>" >&2
echo "$RES" >&2
echo "<<<RES" >&2

# Declare the COMPLETE, fixed set of behavioral check names with their weights.
# We seed every name as 0, then upgrade to the python verdict if a matching
# line was emitted. This guarantees a constant denominator: even if the python
# block crashed entirely (no output at all), every declared check still scores.
declare -A bpass
declare -A bweight
declare -a border
declare_b() { border+=("$1"); bpass["$1"]=0; bweight["$1"]="$2"; }

declare_b "imports" 6
for i in 1 2 3 4 5 6 7; do
  declare_b "t${i}_rt" 4
  declare_b "t${i}_len" 4
  declare_b "t${i}_prefix" 4
done
declare_b "empty_codes" 4
declare_b "empty_encode" 4
declare_b "empty_decode" 4

declare -A bnote
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  [[ "$name" == "IMPORT_ERR" ]] && continue
  # Only honor names we declared (ignore stray output).
  if [[ -n "${bweight[$name]+x}" ]]; then
    [[ "$pass" == "1" ]] && bpass["$name"]=1 || bpass["$name"]=0
    bnote["$name"]="$note"
  fi
done < <(printf '%s\n' "$RES")

for name in "${border[@]}"; do
  add "$name" "${bpass[$name]}" "${bweight[$name]}" "${bnote[$name]:-}"
done

total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in ${checks[@]+"${checks[@]}"}; do
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
