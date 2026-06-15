#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/jsv.py"
add "file:jsv.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  if grep -qE "^\s*import\s+jsonschema|from\s+jsonschema" "$T"; then
    add "no_jsonschema" 0 10 "third-party jsonschema imported"
  else
    add "no_jsonschema" 1 10
  fi
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys
try: from jsv import validate
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)

def passes(inst, sch): return len(validate(inst, sch)) == 0
def fails(inst, sch): return len(validate(inst, sch)) > 0

# string type
print("type_str_ok",  1 if passes("hi", {"type":"string"}) else 0)
print("type_str_bad", 1 if fails(123, {"type":"string"}) else 0)
# integer type - must reject bool (bool is int subclass in python; spec says no)
print("type_int_ok",  1 if passes(5, {"type":"integer"}) else 0)
print("type_int_bool", 1 if fails(True, {"type":"integer"}) else 0)
# object with required + properties
sch = {"type":"object","properties":{"name":{"type":"string"},"age":{"type":"integer","minimum":0}},"required":["name"]}
print("obj_ok",        1 if passes({"name":"a","age":5}, sch) else 0)
print("obj_missing",   1 if fails({"age":5}, sch) else 0)
print("obj_bad_age",   1 if fails({"name":"a","age":"x"}, sch) else 0)
print("obj_neg_age",   1 if fails({"name":"a","age":-1}, sch) else 0)
# array with items + minItems
asch = {"type":"array","items":{"type":"integer"},"minItems":2}
print("arr_ok",        1 if passes([1,2,3], asch) else 0)
print("arr_short",     1 if fails([1], asch) else 0)
print("arr_wrong_item",1 if fails([1,"x",3], asch) else 0)
# string length
print("str_too_short", 1 if fails("a", {"type":"string","minLength":3}) else 0)
print("str_too_long",  1 if fails("abcde", {"type":"string","maxLength":3}) else 0)
# enum
print("enum_ok",       1 if passes("blue", {"enum":["red","green","blue"]}) else 0)
print("enum_bad",      1 if fails("yellow", {"enum":["red","green","blue"]}) else 0)
# pattern
print("pattern_ok",    1 if passes("abc123", {"type":"string","pattern":r"^[a-z0-9]+$"}) else 0)
print("pattern_bad",   1 if fails("abc-123", {"type":"string","pattern":r"^[a-z0-9]+$"}) else 0)
# number minimum/maximum
print("num_min_bad",   1 if fails(0.5, {"type":"number","minimum":1.0}) else 0)
print("num_max_bad",   1 if fails(10.5, {"type":"number","maximum":10}) else 0)
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    add "$name" "$pass" 4 "$note"
  done < <(echo "$RES")
else
  for n in compiles type_str_ok obj_missing; do add "$n" 0 5; done
fi
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
