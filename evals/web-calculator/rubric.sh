#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
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
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

# --- This is a SHOWCASE eval ----------------------------------------------
# The point is the produced artifact (a playable calculator embedded in a
# gallery). The rubric only does LIGHT, STRUCTURAL scoring: it cannot tell if
# the calculator is pretty or even bug-free. It checks the file exists, is
# non-trivial, and references the real APIs/elements a keyboard-driven
# calculator must use. Pure bash + grep/python: NO browser, NO network, NO
# clock - hermetic and deterministic. Every check is predeclared; a missing
# file scores 0 on every check so the denominator is CONSTANT.

T="$WS/index.html"
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:index.html" "$file_ok" 10 "$([[ "$file_ok" == 1 ]] || echo 'index.html missing')"

# Lowercased copy of the source for case-insensitive token checks. If the file
# is missing we leave SRC empty so every grep below cleanly returns no-match
# (-> the check scores 0) rather than erroring out.
SRC=""
nbytes=0
if [[ "$file_ok" == "1" ]]; then
  SRC="$(tr 'A-Z' 'a-z' < "$T" 2>/dev/null)"
  nbytes=$(wc -c < "$T" 2>/dev/null | tr -d ' ')
  [[ -z "$nbytes" ]] && nbytes=0
fi
echo "bytes=$nbytes" >&2

# has() : 1 if the (already-lowercased) extended-regex matches the source.
# Always defined; on a missing file SRC is empty so it returns 0.
has() {
  printf '%s' "$SRC" | grep -Eq "$1" && echo 1 || echo 0
}

# --- non-trivial size ------------------------------------------------------
size_ok=0; [[ "$nbytes" -ge 800 ]] && size_ok=1
add "nontrivial_size" "$size_ok" 10 "bytes=$nbytes (need >=800)"

# --- skeleton: <html>, <body>, a <script> ----------------------------------
add "has_html_tag"   "$(has '<html')"   5
add "has_body_tag"   "$(has '<body')"   5
add "has_script_tag" "$(has '<script')" 5

# --- key calculator APIs / elements ---------------------------------------
# A real button grid: at least a couple of <button ...> elements. Some models
# build the grid from <div> tiles + click handlers instead, so accept either a
# real <button or a data-/onclick driven tile, but require buttons primarily.
btn_ok=0
nbtn=$(printf '%s' "$SRC" | grep -oE '<button' | wc -l | tr -d ' ')
[[ -z "$nbtn" ]] && nbtn=0
if [[ "$nbtn" -ge 4 ]]; then
  btn_ok=1
elif [[ "$(has 'onclick')" == 1 || "$(has 'data-(key|val|op|digit|num)')" == 1 ]]; then
  btn_ok=1
fi
add "button_grid" "$btn_ok" 12 "buttons=$nbtn"

# The four operators must all appear as quoted/escaped tokens somewhere in the
# JS or markup. We look for each operator character; a calculator that omits
# one of +,-,*,/ is not complete. Build an explicit per-operator tally.
op_plus=$(has "\\+")
# minus/star/slash: match the literal character classes (lenient about quoting)
op_minus=$(printf '%s' "$SRC" | grep -Eq '[-\x2d]' && echo 1 || echo 0)
op_star=$(printf '%s' "$SRC" | grep -Fq '*' && echo 1 || echo 0)
op_slash=$(printf '%s' "$SRC" | grep -Fq '/' && echo 1 || echo 0)
ops_ok=0
[[ "$op_plus" == 1 && "$op_minus" == 1 && "$op_star" == 1 && "$op_slash" == 1 ]] && ops_ok=1
add "all_four_operators" "$ops_ok" 12 "plus=$op_plus minus=$op_minus star=$op_star slash=$op_slash"

# Decimal point support: a '.' digit button or decimal handling. Look for a
# decimal token in markup/JS (a quoted '.', or 'decimal'/'dot' identifiers).
dec_ok=0
if printf '%s' "$SRC" | grep -Eq "['\"]\.['\"]|decimal|>\\.<|dot|[0-9]\." ; then
  dec_ok=1
fi
add "decimal_support" "$dec_ok" 8 "$([[ "$dec_ok" == 1 ]] || echo 'no decimal token found')"

# Clear: a clear/AC/C button or a clear() handler.
clr_ok=0
if printf '%s' "$SRC" | grep -Eq "clear|>ac<|>c<|reset|allclear|all-clear" ; then
  clr_ok=1
fi
add "clear_button" "$clr_ok" 8 "$([[ "$clr_ok" == 1 ]] || echo 'no clear token found')"

# Keyboard input: a keydown / keyup / keypress listener.
key_ok=0
if printf '%s' "$SRC" | grep -Eq "addeventlistener\\([\"']key(down|up|press)|onkey(down|up|press)|\\.key[ ]*[=!]==?|event\\.key|e\\.key" ; then
  key_ok=1
fi
add "keyboard_input" "$key_ok" 10 "$([[ "$key_ok" == 1 ]] || echo 'no key handler found')"

# A display element: an element that shows the running value. Accept an id/class
# named display/screen/result/output/input, or an <input> field.
disp_ok=0
if printf '%s' "$SRC" | grep -Eq "(id|class)=[\"'][^\"']*(display|screen|result|output|calc-?input)|<input" ; then
  disp_ok=1
fi
add "display_element" "$disp_ok" 8 "$([[ "$disp_ok" == 1 ]] || echo 'no display element found')"

# --- balanced-tags sanity --------------------------------------------------
# Rough heuristic only: <div opens vs </div> closes shouldn't be wildly off,
# OR <html> is properly closed. Defensive against missing file (counts -> 0).
opendiv=0; closediv=0; htmlclosed=0
if [[ "$file_ok" == "1" ]]; then
  opendiv=$(printf '%s' "$SRC" | grep -oE '<div' | wc -l | tr -d ' ')
  closediv=$(printf '%s' "$SRC" | grep -oE '</div' | wc -l | tr -d ' ')
  [[ -z "$opendiv" ]] && opendiv=0
  [[ -z "$closediv" ]] && closediv=0
  printf '%s' "$SRC" | grep -Eq '</html' && htmlclosed=1
fi
diff=$(( opendiv > closediv ? opendiv - closediv : closediv - opendiv ))
bal_ok=0
# Tolerate a small mismatch (<=2) OR an explicitly closed <html>.
if [[ "$file_ok" == "1" ]] && { [[ "$diff" -le 2 ]] || [[ "$htmlclosed" == 1 ]]; }; then
  bal_ok=1
fi
add "balanced_tags" "$bal_ok" 10 "div_open=$opendiv div_close=$closediv html_closed=$htmlclosed"

# --- emit -----------------------------------------------------------------
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
