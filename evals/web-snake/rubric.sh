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

# ---------------------------------------------------------------------------
# SHOWCASE eval: this is a LIGHT, STRUCTURAL rubric. The real payoff is the
# produced index.html getting embedded in a playable gallery - a script cannot
# judge whether a Snake game is fun, only that the artifact has the right shape
# and references the real browser APIs the task needs. Every check is predeclared
# and a missing file scores 0 on every check (constant denominator), mirroring
# evals/matrix-ops/rubric.sh.
# ---------------------------------------------------------------------------

T="$WS/index.html"
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:index.html" "$file_ok" 10

# Size: non-trivial HTML (>= 800 bytes). 0 if file missing.
size_ok=0
if [[ "$file_ok" == "1" ]]; then
  bytes=$(wc -c < "$T" 2>/dev/null | tr -d ' ')
  [[ -z "$bytes" ]] && bytes=0
  [[ "$bytes" -ge 800 ]] && size_ok=1
  echo "SIZE bytes=$bytes" >&2
fi
add "size>=800B" "$size_ok" 10

# All remaining token checks run in a single python pass that ALWAYS prints one
# line per declared check (pass/fail), whether or not the file exists - so the
# denominator never changes. Tokens are matched case-insensitively and leniently
# (models vary wildly in formatting) but still require the real APIs.
RES=$(WS="$WS" python3 - <<'PY' 2>>/dev/null
import os, re, sys

ws = os.environ["WS"]
path = os.path.join(ws, "index.html")
try:
    with open(path, "rb") as f:
        raw = f.read().decode("utf-8", "replace")
except Exception:
    raw = ""
low = raw.lower()

def emit(name, passed, note=""):
    note = str(note).replace("\\", "").replace('"', "'").replace("\n", " ").replace("\t", " ")
    print(name, 1 if passed else 0, note)

def has_any(*subs):
    return any(s in low for s in subs)

def has_re(pat):
    return re.search(pat, low) is not None

# --- skeleton: <html>/<body> + a <script> (weight handled in bash) ---
skeleton = ("<html" in low) and ("<body" in low) and ("<script" in low)
emit("html_skeleton", skeleton, "" if skeleton else "missing <html>/<body>/<script>")

# --- canvas element + 2D context ---
canvas_ok = ("<canvas" in low) and ("getcontext" in low)
emit("canvas+getContext", canvas_ok, "" if canvas_ok else "need <canvas> and getContext")

# --- animation loop ---
raf_ok = "requestanimationframe" in low
emit("requestAnimationFrame", raf_ok, "" if raf_ok else "no requestAnimationFrame loop")

# --- keyboard control: keydown listener wired up ---
key_ok = ("addeventListener".lower() in low and "keydown" in low) or has_re(r'onkeydown\s*=')
emit("keydown_handler", key_ok, "" if key_ok else "no keydown listener")

# --- arrow keys AND/OR WASD referenced (movement input) ---
arrows = has_any("arrowup", "arrowdown", "arrowleft", "arrowright", "keycode") or \
         has_re(r'["\']arrow')
wasd = has_re(r'["\'][wasd]["\']') or has_any('case "w"', "case 'w'", '"w":', "'w':")
move_ok = arrows or wasd
emit("arrow_or_wasd_keys", move_ok, "" if move_ok else "no arrow/WASD key tokens")

# --- score display referenced ---
score_ok = "score" in low
emit("score_display", score_ok, "" if score_ok else "no score reference")

# --- food / fruit / apple concept present ---
food_ok = has_any("food", "fruit", "apple")
emit("food", food_ok, "" if food_ok else "no food/fruit/apple token")

# --- game over / collision -> restart concept present ---
gameover = has_any("game over", "gameover", "game_over", "you lose", "you died")
restart = has_any("restart", "play again", "try again", "reset", "location.reload")
over_ok = gameover and restart
emit("gameover+restart", over_ok, "" if over_ok else "need game-over and restart")

# --- self-contained: no external script/link references ---
ext_script = has_re(r'<script[^>]*\bsrc\s*=')
ext_link = has_re(r'<link[^>]*\bhref\s*=') and "stylesheet" in low
http_ref = has_any("http://", "https://", "//cdn", "cdnjs", "unpkg", "jsdelivr")
selfcontained = (not ext_script) and (not ext_link) and (not http_ref) and (raw != "")
emit("self_contained", selfcontained,
     "" if selfcontained else "references external/CDN assets")

# --- balanced-tags sanity: <div> opens vs </div> closes not wildly off,
#     OR the document is properly closed (</html>). Lenient on purpose. ---
opens = len(re.findall(r'<div\b', low))
closes = len(re.findall(r'</div>', low))
html_closed = "</html>" in low
balanced = (raw != "") and (html_closed or abs(opens - closes) <= 2)
emit("balanced_tags", balanced,
     ("opens=%d closes=%d closed=%s" % (opens, closes, html_closed)) if not balanced else "")
PY
)
echo "$RES" >&2

# Weights for each python-emitted check (constant denominator). Total across the
# python checks = 15+15+10+10+8+8+8+8+8+10 = 100, plus file(10)+size(10) above
# would over-shoot, so the token weights below are tuned so file+size+tokens sum
# to ~100 with the structural checks carrying ~50-60 spread across 4-6 of them.
declare -A WEIGHT=(
  [html_skeleton]=8
  [canvas+getContext]=15
  [requestAnimationFrame]=12
  [keydown_handler]=12
  [arrow_or_wasd_keys]=6
  [score_display]=6
  [food]=6
  [gameover+restart]=8
  [self_contained]=7
  [balanced_tags]=10
)

declare -A SEEN
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  w="${WEIGHT[$name]:-}"
  [[ -z "$w" ]] && continue
  add "$name" "$pass" "$w" "$note"
  SEEN["$name"]=1
done < <(printf '%s\n' "$RES")

# Safety net: if the python crashed catastrophically (e.g. interpreter missing)
# so a declared check never printed, add it as a 0 so the denominator stays
# constant no matter what the submission (or the environment) does.
for n in html_skeleton "canvas+getContext" requestAnimationFrame keydown_handler \
         arrow_or_wasd_keys score_display food "gameover+restart" self_contained \
         balanced_tags; do
  [[ -z "${SEEN[$n]:-}" ]] && add "$n" 0 "${WEIGHT[$n]}" "no output from rubric"
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
