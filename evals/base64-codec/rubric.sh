#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
sanitize() {
  # strip backslashes and replace double-quotes with single, collapse to one line
  printf '%s' "$1" | tr -d '\\' | tr '"' "'" | tr '\n\t' '  '
}
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  note="$(sanitize "$note")"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/base64codec.py"

# --- static checks (always emitted) ---
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:base64codec.py" "$file_ok" 5

compiles_ok=0
if [[ "$file_ok" == "1" ]] && python3 -m py_compile "$T" 2>/dev/null; then
  compiles_ok=1
fi
add "compiles" "$compiles_ok" 5

# no_stdlib_base64: pass(1) if file exists AND does not import base64.
# A missing file cannot "not import base64" meaningfully -> treat as 0 so a
# non-existent submission never harvests this weight for free.
if [[ "$file_ok" == "1" ]]; then
  if grep -qE "^[[:space:]]*import[[:space:]]+base64|from[[:space:]]+base64" "$T"; then
    add "no_stdlib_base64" 0 10 "imports base64 module"
  else
    add "no_stdlib_base64" 1 10
  fi
else
  add "no_stdlib_base64" 0 10 "file missing"
fi

# --- behavioral checks ---
# CONSTANT DENOMINATOR: the full list of behavioral check names is declared HERE
# in bash. The python block ALWAYS prints one line per name via chk() (even on
# import error or per-case exception), but if python crashes entirely or is
# killed by gtimeout, the bash side still emits every declared name as pass=0.
# So every declared check is ALWAYS scored - never skipped, never aborted.
BEHAV_NAMES=(
  enc1 rt1 enc2 rt2 enc3 rt3 enc4 rt4 enc5 rt5
  enc6 rt6 enc7 rt7 enc8 rt8 enc9 rt9
  ws_tolerant rejects_invalid
)
BEHAV_WEIGHT=4

RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>/dev/null
import sys
ok = True
try:
    from base64codec import encode, decode
except Exception as e:
    sys.stderr.write("IMPORT_ERR " + repr(e)[:120] + "\n")
    ok = False

def chk(name, fn):
    if not ok:
        print(name, 0, "import failed")
        return
    try:
        print(name, 1 if fn() else 0)
    except Exception as ex:
        # keep notes short and quote/backslash-free; add()'s sanitize is backup
        msg = repr(ex)[:50].replace('"', "'").replace("\\", "")
        print(name, 0, "ERR", msg)

CASES = [
    (b"",              ""),
    (b"f",             "Zg=="),
    (b"fo",            "Zm8="),
    (b"foo",           "Zm9v"),
    (b"foob",          "Zm9vYg=="),
    (b"fooba",         "Zm9vYmE="),
    (b"foobar",        "Zm9vYmFy"),
    (b"Hello, World!", "SGVsbG8sIFdvcmxkIQ=="),
    (b"\x00\x01\x02\x03\xff", "AAECA/8="),
]
for i, (data, expected) in enumerate(CASES, 1):
    chk(f"enc{i}", (lambda d=data, e=expected: encode(d) == e))
    chk(f"rt{i}",  (lambda d=data: decode(encode(d)) == d))

# decode tolerates embedded whitespace
chk("ws_tolerant", (lambda: decode("Zm9v\n Yg==") == b"foob"))

# decode invalid chars raises ValueError
def _rejects():
    try:
        decode("!!!!")
    except ValueError:
        return True
    except Exception:
        return False
    return False
chk("rejects_invalid", _rejects)
PY
)
echo "$RES" >&2

# Parse python output into name -> "pass<TAB>note". Missing names default to 0.
declare -A B_PASS B_NOTE
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  B_PASS["$name"]="$pass"
  B_NOTE["$name"]="$note"
done < <(printf '%s\n' "$RES")

# Emit every declared behavioral check, in fixed order, at the same weight.
for name in "${BEHAV_NAMES[@]}"; do
  p="${B_PASS[$name]:-0}"
  nt="${B_NOTE[$name]:-no result emitted}"
  add "$name" "$p" "$BEHAV_WEIGHT" "$nt"
done

# Explicit imports check: directly reflects whether the required API imported.
imports_ok=0
if [[ "$file_ok" == "1" ]]; then
  if (cd "$WS" && gtimeout 10 python3 -c "from base64codec import encode, decode" 2>/dev/null); then
    imports_ok=1
  fi
fi
add "imports" "$imports_ok" 6 "$([[ "$imports_ok" == 1 ]] || echo 'encode/decode not importable')"

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
