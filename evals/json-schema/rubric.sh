#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
# sanitize_note: strip backslashes and double-quotes so notes can't corrupt the
# final JSON (see CLAUDE.md rubric gotcha #2).
sanitize_note() {
  local s="$1"
  s="${s//\\/ }"   # drop backslashes
  s="${s//\"/\'}"  # double-quote -> single-quote
  s="${s//$'\t'/ }"
  s="${s//$'\n'/ }"
  printf '%s' "$s"
}
add() {
  local n="$1" p="$2" w="$3" note
  note="$(sanitize_note "${4:-}")"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

# The complete, FIXED list of behavioral checks. Declared up front so the
# denominator is CONSTANT regardless of how broken the submission is. Each is
# emitted exactly once below; any case that is not produced by the python block
# (import error, crash, abort) is back-filled as a 0 here. Order is preserved.
BEHAVIOR_CHECKS=(
  type_str_ok type_str_bad
  type_int_ok type_int_bool
  obj_ok obj_missing obj_bad_age obj_neg_age
  arr_ok arr_short arr_wrong_item
  str_too_short str_too_long
  enum_ok enum_bad
  pattern_ok pattern_bad
  num_min_bad num_max_bad
)
BEHAVIOR_WEIGHT=4

T="$WS/jsv.py"
file_exists=0
[[ -f "$T" ]] && file_exists=1
add "file:jsv.py" "$file_exists" 5

# Static checks (compile, no third-party jsonschema). Always emitted.
if [[ "$file_exists" == "1" ]]; then
  if python3 -m py_compile "$T" 2>/dev/null; then add "compiles" 1 5; else add "compiles" 0 5; fi
  if grep -qE "^\s*import\s+jsonschema|from\s+jsonschema" "$T"; then
    add "no_jsonschema" 0 10 "third-party jsonschema imported"
  else
    add "no_jsonschema" 1 10
  fi
else
  add "compiles" 0 5
  add "no_jsonschema" 0 10 "file missing"
fi

# Behavioral block. The python NEVER sys.exit()s on import error and NEVER lets
# one failing case abort the rest: chk() always prints "<name> <1|0> [note]".
# An explicit "imports" line reflects whether validate could be imported at all.
declare -A RESULT
declare -A NOTE
imports_ok=0
if [[ "$file_exists" == "1" ]]; then
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>/dev/null
import sys

ok = True
try:
    from jsv import validate
except Exception as e:
    print("IMPORT_ERR", repr(e), file=sys.stderr)
    ok = False

print("imports", 1 if ok else 0)

def passes(inst, sch):
    return len(validate(inst, sch)) == 0

def fails(inst, sch):
    return len(validate(inst, sch)) > 0

def chk(name, fn):
    if not ok:
        print(name, 0, "import failed")
        return
    try:
        print(name, 1 if fn() else 0)
    except Exception as ex:
        print(name, 0, repr(ex)[:60])

# string type
chk("type_str_ok",  lambda: passes("hi", {"type":"string"}))
chk("type_str_bad", lambda: fails(123, {"type":"string"}))
# integer type - must reject bool (bool is int subclass in python; spec says no)
chk("type_int_ok",  lambda: passes(5, {"type":"integer"}))
chk("type_int_bool",lambda: fails(True, {"type":"integer"}))
# object with required + properties
_sch = {"type":"object","properties":{"name":{"type":"string"},"age":{"type":"integer","minimum":0}},"required":["name"]}
chk("obj_ok",       lambda: passes({"name":"a","age":5}, _sch))
chk("obj_missing",  lambda: fails({"age":5}, _sch))
chk("obj_bad_age",  lambda: fails({"name":"a","age":"x"}, _sch))
chk("obj_neg_age",  lambda: fails({"name":"a","age":-1}, _sch))
# array with items + minItems
_asch = {"type":"array","items":{"type":"integer"},"minItems":2}
chk("arr_ok",       lambda: passes([1,2,3], _asch))
chk("arr_short",    lambda: fails([1], _asch))
chk("arr_wrong_item",lambda: fails([1,"x",3], _asch))
# string length
chk("str_too_short",lambda: fails("a", {"type":"string","minLength":3}))
chk("str_too_long", lambda: fails("abcde", {"type":"string","maxLength":3}))
# enum
chk("enum_ok",      lambda: passes("blue", {"enum":["red","green","blue"]}))
chk("enum_bad",     lambda: fails("yellow", {"enum":["red","green","blue"]}))
# pattern
chk("pattern_ok",   lambda: passes("abc123", {"type":"string","pattern":r"^[a-z0-9]+$"}))
chk("pattern_bad",  lambda: fails("abc-123", {"type":"string","pattern":r"^[a-z0-9]+$"}))
# number minimum/maximum
chk("num_min_bad",  lambda: fails(0.5, {"type":"number","minimum":1.0}))
chk("num_max_bad",  lambda: fails(10.5, {"type":"number","maximum":10}))
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(printf '%s' "$line" | awk '{print $1}')
    pass=$(printf '%s' "$line" | awk '{print $2}')
    note=$(printf '%s' "$line" | cut -d' ' -f3-)
    if [[ "$name" == "imports" ]]; then
      [[ "$pass" == "1" ]] && imports_ok=1 || imports_ok=0
      continue
    fi
    RESULT["$name"]="$pass"
    NOTE["$name"]="$note"
  done < <(printf '%s\n' "$RES")
else
  echo "jsv.py missing - all behavioral checks score 0" >&2
fi

# explicit imports check (penalizes a non-importing / missing file directly)
add "imports" "$imports_ok" 6 "$([[ "$imports_ok" == "1" ]] || echo 'validate not importable')"

# Emit EVERY behavioral check exactly once - constant denominator. Anything the
# python block did not produce (crash/abort/missing) defaults to 0.
for name in "${BEHAVIOR_CHECKS[@]}"; do
  p="${RESULT[$name]:-0}"
  n="${NOTE[$name]:-}"
  [[ -z "${RESULT[$name]:-}" && "$file_exists" == "1" ]] && n="not emitted"
  add "$name" "$p" "$BEHAVIOR_WEIGHT" "$n"
done

total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in "${checks[@]}"; do
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
