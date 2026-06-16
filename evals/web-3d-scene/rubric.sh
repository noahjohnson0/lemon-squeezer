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
add "file:index.html" "$file_ok" 10 "$([[ $file_ok == 1 ]] || printf 'missing index.html')"

# All structural/token checks run inside one python heredoc that ALWAYS prints
# exactly one line per declared check, whether the file exists or not. That
# keeps the denominator constant across submissions (empty, partial, correct).
# Diagnostics go to stderr; only the per-check lines go to stdout (captured).
RES=$(WS="$WS" python3 - <<'PY' 2>>/dev/null
import os, re

ws = os.environ["WS"]
path = os.path.join(ws, "index.html")

raw = ""
try:
    with open(path, "rb") as f:
        raw = f.read().decode("utf-8", "replace")
except Exception:
    raw = ""

# Case-insensitive haystack for token checks; be lenient about formatting.
low = raw.lower()
nbytes = len(raw.encode("utf-8"))

def emit(name, passed, note=""):
    note = str(note).replace("\\", "").replace('"', "'").replace("\n", " ").replace("\t", " ")
    print(name, 1 if passed else 0, note)

def has(*subs):
    return all(s.lower() in low for s in subs)

def has_any(*subs):
    return any(s.lower() in low for s in subs)

def rx(pattern):
    return re.search(pattern, low, re.IGNORECASE | re.DOTALL) is not None

# 1) non-trivial size (>= 800 bytes)
emit("nontrivial_size", nbytes >= 800, "bytes=%d" % nbytes)

# 2) html skeleton: <html> ... <body> ... and a <script> tag present
emit("html_skeleton", has("<html") and has("<body") and has("<script"), "" if (has("<html") and has("<body") and has("<script")) else "need html/body/script")

# 3) loads three.js from a CDN <script src=...three...>
cdn = rx(r"<script[^>]+src\s*=\s*[\"'][^\"']*three[^\"']*[\"']")
emit("threejs_cdn", cdn, "" if cdn else "no three.js CDN script tag")

# 4) uses the THREE namespace / core API (scene + renderer)
three_api = has("three.") or has("new three")
scene = has("scene")
renderer = has("webglrenderer") or has("renderer")
emit("three_core", three_api and scene and renderer, "" if (three_api and scene and renderer) else "need THREE. + Scene + Renderer")

# 5) lighting present (any common three.js light)
light = has_any("light(", "directionallight", "pointlight", "ambientlight", "hemispherelight", "spotlight")
emit("lighting", light, "" if light else "no light found")

# 6) a renderable mesh / geometry (the 3D object)
geom = has_any("geometry", "mesh", "torusknot", "boxgeometry", "spheregeometry")
emit("geometry", geom, "" if geom else "no geometry/mesh")

# 7) animation loop via requestAnimationFrame
raf = has("requestanimationframe")
emit("animation_loop", raf, "" if raf else "no requestAnimationFrame")

# 8) animates/rotates the object across frames
rotate = has_any("rotation.", ".rotatey", ".rotatex", "rotateonaxis", "orbitcontrols")
emit("rotation", rotate, "" if rotate else "no rotation/animation of object")

# 9) mouse-drag orbit interactivity (hand-rolled listeners OR OrbitControls)
hand_rolled = has("addeventlistener") and has_any("mousemove", "pointermove") and has_any("mousedown", "pointerdown")
orbit = has("orbitcontrols")
drag = hand_rolled or orbit
emit("mouse_drag", drag, "" if drag else "no mouse-drag orbit (listeners or OrbitControls)")

# 10) camera defined (perspective/orthographic)
cam = has_any("perspectivecamera", "orthographiccamera", "camera")
emit("camera", cam, "" if cam else "no camera")

# 11) balanced-tags sanity: <div> roughly matched, and <html> is closed.
opens = low.count("<div")
closes = low.count("</div>")
html_closed = "</html>" in low
# tolerate a small imbalance (self-closing-ish authoring varies)
div_ok = abs(opens - closes) <= 2
# require real markup so an empty/missing file cannot earn this for free
balanced = bool(raw.strip()) and div_ok and html_closed
emit("balanced_tags", balanced, "div_open=%d div_close=%d html_closed=%s" % (opens, closes, html_closed))
PY
)
printf '%s\n' "$RES" >&2

# Weights for each declared structural check. Folded in below at these weights;
# anything that fails to print (catastrophic python failure) is added as 0 so
# the denominator never moves.
declare -A W=(
  [nontrivial_size]=10
  [html_skeleton]=15
  [threejs_cdn]=10
  [three_core]=12
  [lighting]=8
  [geometry]=8
  [animation_loop]=10
  [rotation]=8
  [mouse_drag]=12
  [camera]=7
  [balanced_tags]=10
)

declare -A SEEN
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  w="${W[$name]:-}"
  [[ -z "$w" ]] && continue
  add "$name" "$pass" "$w" "$note"
  SEEN["$name"]=1
done < <(printf '%s\n' "$RES")

# Safety net: if python crashed so a declared check never printed, add it as 0
# so the total weight is identical for every submission.
for n in nontrivial_size html_skeleton threejs_cdn three_core lighting geometry animation_loop rotation mouse_drag camera balanced_tags; do
  [[ -z "${SEEN[$n]:-}" ]] && add "$n" 0 "${W[$n]}" "no output from rubric"
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
