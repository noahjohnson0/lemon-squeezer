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

T="$WS/index.html"
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:index.html" "$file_ok" 10 "$([[ $file_ok == 1 ]] && echo found || echo missing)"

# SHOWCASE eval: this is a LIGHT, STRUCTURAL rubric. The point is the produced
# artifact (it gets embedded in a playable gallery), so we cannot judge whether
# the toy is fun - we only verify the file exists, is non-trivial, and actually
# references the real canvas/animation/mouse APIs the task demands.
#
# All token checks run in one python heredoc that ALWAYS prints exactly one line
# per declared check (pass note...), whether the file exists or not. That keeps
# the denominator constant for every submission (missing file -> every check 0,
# never skipped). The file is read case-insensitively and we are lenient about
# formatting (models vary) but require the genuine APIs. Everything here is pure
# python string/regex work: no headless browser, no network, no clock.
RES=$(WS="$WS" python3 - <<'PY' 2>&1
import os, re, sys

ws = os.environ["WS"]
path = os.path.join(ws, "index.html")

raw = ""
try:
    with open(path, "rb") as f:
        raw = f.read().decode("utf-8", "replace")
except Exception as e:
    print("READ_ERR", repr(e)[:80], file=sys.stderr)

low = raw.lower()
size = len(raw.encode("utf-8"))

def emit(name, passed, note=""):
    note = str(note).replace("\\", "").replace('"', "'").replace("\n", " ").replace("\t", " ")
    print(name, 1 if passed else 0, note)

def has(*subs):
    # case-insensitive substring OR-match
    return any(s.lower() in low for s in subs)

def has_re(pattern):
    return re.search(pattern, low, re.I | re.S) is not None

# --- non-trivial size (>= 800 bytes) -------------------------------------
emit("nontrivial_size", size >= 800, "bytes=%d" % size)

# --- skeleton: <html> + <body> + a <script> ------------------------------
skeleton = has("<html") and has("<body") and has("<script")
emit("html_skeleton", skeleton, "html/body/script present" if skeleton else "missing html/body/script")

# --- key APIs this task needs --------------------------------------------
# 1) a <canvas> element
emit("has_canvas", has("<canvas"), "canvas tag")
# 2) a 2D drawing context
emit("getcontext", has("getcontext"), "getContext")
# 3) a smooth animation loop
emit("raf", has("requestanimationframe"), "requestAnimationFrame")
# 4) mouse interaction: a mouse event wired via addEventListener
mouse = has("addeventlistener") and has(
    "mousemove", "mousedown", "click", "pointermove", "pointerdown"
)
emit("mouse_handler", mouse, "addEventListener + mouse/pointer/click")
# 5) window resize handling (canvas adapts to the window)
resize = has_re(r"addeventlistener\s*\(\s*['\"]resize['\"]") or (
    has("resize") and has("innerwidth", "innerheight", "canvas.width", "canvas.height")
)
emit("resize", resize, "resize handling")

# --- balanced-tags sanity ------------------------------------------------
# Rough heuristic only: the <html> element is closed, and the count of opening
# vs closing <div tags is not wildly off (models indent/minify differently).
html_closed = ("<html" not in low) or ("</html>" in low)
open_div = len(re.findall(r"<div\b", low))
close_div = len(re.findall(r"</div>", low))
div_ok = abs(open_div - close_div) <= 2
emit("balanced_tags", (html_closed and div_ok),
     "html_closed=%s div %d/%d" % (html_closed, open_div, close_div))
PY
)
echo "$RES" >&2

# Fold each emitted token line in. The python ALWAYS prints every declared
# check, so the denominator never changes across submissions.
declare -A WEIGHTS=(
  [nontrivial_size]=10
  [html_skeleton]=15
  [has_canvas]=12
  [getcontext]=12
  [raf]=12
  [mouse_handler]=12
  [resize]=12
  [balanced_tags]=10
)

declare -A SEEN
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  [[ "$name" == "READ_ERR" ]] && continue
  [[ -z "${WEIGHTS[$name]:-}" ]] && continue
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  add "$name" "$pass" "${WEIGHTS[$name]}" "$note"
  SEEN["$name"]=1
done < <(printf '%s\n' "$RES")

# Safety net: if the python crashed catastrophically (e.g. interpreter missing)
# so a declared check never printed, add it as a 0 so the denominator stays
# constant no matter what.
for n in nontrivial_size html_skeleton has_canvas getcontext raf mouse_handler resize balanced_tags; do
  [[ -z "${SEEN[$n]:-}" ]] && add "$n" 0 "${WEIGHTS[$n]}" "no output from rubric"
done

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
