#!/usr/bin/env bash
# Score the multifile-refactor-validators workspace.
#  - Behavioral checks: every field kind validates correctly AND consistently
#    (the whitespace-only "required" inconsistency must be fixed), public API
#    unchanged.
#  - Structural checks: duplication was actually reduced (a shared module now
#    exists & the per-field copies of the "required" literal are gone).
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  # sanitize note: drop backslashes, turn double quotes into single quotes
  note="${note//\\/}"
  note="${note//\"/\'}"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

PKG="$WS/validators"
add "file:validators/api.py" "$([[ -f "$PKG/api.py" ]] && echo 1 || echo 0)" 4

# ---------------------------------------------------------------------------
# Behavioral checks via an embedded python loader. Emits "<name> <0|1> <note>"
# lines on stdout (captured), diagnostics on stderr.
# ---------------------------------------------------------------------------
if [[ -f "$PKG/api.py" ]]; then
  RES=$(cd "$WS" && gtimeout 15 python3 - <<'PY' 2>&1
import sys
try:
    from validators import validate, is_valid, FIELD_KINDS
except Exception as e:
    print("IMPORT_ERR import failed:", type(e).__name__, str(e).replace('"',"'"))
    sys.exit(1)

KINDS = ("email", "phone", "postcode", "name")

def emit(name, cond, note=""):
    print(name, 1 if cond else 0, note)

# 0) FIELD_KINDS still advertises the four field kinds
try:
    emit("api_field_kinds", set(FIELD_KINDS) == set(KINDS), "got=%r" % (tuple(FIELD_KINDS),))
except Exception as e:
    emit("api_field_kinds", False, repr(e).replace('"',"'"))

# 1) valid samples -> (True, None) for every kind (consistent shape)
valids = {
    "email": "a@b.com",
    "phone": "+1 (555) 123-4567",
    "postcode": "SW1A 1AA",
    "name": "Ada Lovelace",
}
ok_all = True
detail = []
for k in KINDS:
    try:
        r = validate(k, valids[k])
    except Exception as e:
        r = ("EXC", repr(e))
    if r != (True, None):
        ok_all = False
        detail.append("%s=%r" % (k, r))
emit("valid_inputs_pass", ok_all, ("bad:" + ",".join(detail)) if detail else "")

# 2) empty string "" -> (False, "required") for EVERY kind
ok_all = True; detail = []
for k in KINDS:
    try:
        r = validate(k, "")
    except Exception as e:
        r = ("EXC", repr(e))
    if r != (False, "required"):
        ok_all = False; detail.append("%s=%r" % (k, r))
emit("empty_is_required", ok_all, ("bad:" + ",".join(detail)) if detail else "")

# 3) THE BUG: whitespace-only "   " -> (False, "required") for EVERY kind.
#    In the starter, postcode returns (False, "invalid postcode") here.
ok_all = True; detail = []
for k in KINDS:
    try:
        r = validate(k, "   ")
    except Exception as e:
        r = ("EXC", repr(e))
    if r != (False, "required"):
        ok_all = False; detail.append("%s=%r" % (k, r))
emit("whitespace_is_required", ok_all, ("bad:" + ",".join(detail)) if detail else "")

# 4) None -> (False, "required") for EVERY kind (no crash)
ok_all = True; detail = []
for k in KINDS:
    try:
        r = validate(k, None)
    except Exception as e:
        r = ("EXC", repr(e))
    if r != (False, "required"):
        ok_all = False; detail.append("%s=%r" % (k, r))
emit("none_is_required", ok_all, ("bad:" + ",".join(detail)) if detail else "")

# 5) format errors preserved (valid presence, bad format)
fmt_cases = {
    "email": ("not-an-email", "invalid email"),
    "phone": ("12", "invalid phone"),
    "postcode": ("ZZZZZ", "invalid postcode"),
}
ok_all = True; detail = []
for k, (val, want) in fmt_cases.items():
    try:
        r = validate(k, val)
    except Exception as e:
        r = ("EXC", repr(e))
    if r != (False, want):
        ok_all = False; detail.append("%s=%r want=(False,%r)" % (k, r, want))
emit("format_errors_preserved", ok_all, ("bad:" + ",".join(detail)) if detail else "")

# 6) unknown kind still raises ValueError
try:
    validate("nope", "x")
    emit("unknown_kind_raises", False, "no exception")
except ValueError:
    emit("unknown_kind_raises", True)
except Exception as e:
    emit("unknown_kind_raises", False, type(e).__name__)

# 7) is_valid convenience still works both ways
try:
    good = is_valid("email", "a@b.com") is True
    bad = is_valid("email", "nope") is False
    blank = is_valid("name", "   ") is False
    emit("is_valid_works", good and bad and blank,
         "good=%r bad=%r blank=%r" % (good, bad, blank))
except Exception as e:
    emit("is_valid_works", False, repr(e).replace('"',"'"))
PY
)
  echo "$RES" >&2
  IMPORT_OK=1
  echo "$RES" | grep -q "^IMPORT_ERR" && IMPORT_OK=0

  for name in api_field_kinds valid_inputs_pass empty_is_required \
              whitespace_is_required none_is_required format_errors_preserved \
              unknown_kind_raises is_valid_works; do
    line=$(echo "$RES" | grep "^$name " | head -n1)
    if [[ -z "$line" ]]; then
      add "$name" 0 9 "no result (import failed?)"
    else
      pass=$(echo "$line" | awk '{print $2}')
      note=$(echo "$line" | cut -d' ' -f3-)
      add "$name" "$pass" 9 "$note"
    fi
  done
else
  for name in api_field_kinds valid_inputs_pass empty_is_required \
              whitespace_is_required none_is_required format_errors_preserved \
              unknown_kind_raises is_valid_works; do
    add "$name" 0 9 "no api.py"
  done
fi

# ---------------------------------------------------------------------------
# Structural checks: did duplication actually get reduced?
# ---------------------------------------------------------------------------
FIELD_FILES=()
for f in email_field phone_field postcode_field name_field; do
  [[ -f "$PKG/$f.py" ]] && FIELD_FILES+=("$PKG/$f.py")
done

# (a) A NEW shared module exists in the package (something other than the six
#     original files) AND at least 3 field modules reference it (import it).
SHARED_OK=0
SHARED_NOTE="no new shared module"
if [[ -d "$PKG" ]]; then
  shopt -s nullglob
  for pyf in "$PKG"/*.py; do
    base=$(basename "$pyf")
    case "$base" in
      __init__.py|api.py|email_field.py|phone_field.py|postcode_field.py|name_field.py) continue ;;
    esac
    modname="${base%.py}"
    # how many field modules import this new module by name?
    refs=0
    for ff in ${FIELD_FILES[@]+"${FIELD_FILES[@]}"}; do
      grep -qE "(import[[:space:]]+${modname}\b|from[[:space:]].*import|${modname}\.)" "$ff" \
        && grep -qE "\b${modname}\b" "$ff" && refs=$((refs+1))
    done
    if [[ $refs -ge 3 ]]; then
      SHARED_OK=1
      SHARED_NOTE="shared module $base referenced by $refs field modules"
      break
    else
      SHARED_NOTE="found $base but only $refs field modules reference it"
    fi
  done
  shopt -u nullglob
fi
add "shared_module_extracted" "$SHARED_OK" 12 "$SHARED_NOTE"

# (b) Duplication reduced: the literal "required" should no longer be
#     copy-pasted across the field modules. Starter has it in all four files
#     (7 literal occurrences total). After refactor it should live in the
#     shared module, so the field modules together hold <=1 occurrence.
REQ_COUNT=0
for ff in ${FIELD_FILES[@]+"${FIELD_FILES[@]}"}; do
  c=$(grep -oE '"required"|'\''required'\''' "$ff" 2>/dev/null | wc -l | tr -d ' ')
  REQ_COUNT=$((REQ_COUNT + c))
done
if [[ $REQ_COUNT -le 1 ]]; then
  add "duplication_reduced" 1 12 "'required' literal occurs $REQ_COUNT times across field modules"
else
  add "duplication_reduced" 0 12 "'required' literal still copy-pasted: $REQ_COUNT occurrences across field modules"
fi

# ---------------------------------------------------------------------------
# emit
# ---------------------------------------------------------------------------
total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in ${checks[@]+"${checks[@]}"}; do
    IFS=$'\t' read -r name pass weight note <<<"$c"
    total=$((total+weight))
    [[ "$pass" == "1" ]] && gained=$((gained+weight))
    [[ $first -eq 0 ]] && printf ',\n'
    printf '    {"name":"%s","pass":%s,"weight":%s,"note":"%s"}' "$name" "$pass" "$weight" "$note"
    first=0
  done
  printf '\n  ],\n'
  pct=0
  [[ $total -gt 0 ]] && pct=$(( (gained * 100) / total ))
  printf '  "gained": %s,\n  "total": %s,\n  "score_pct": %s\n}\n' "$gained" "$total" "$pct"
}
