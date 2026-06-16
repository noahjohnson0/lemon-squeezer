#!/usr/bin/env bash
# SHOWCASE eval: web-landing.
# The point of a showcase eval is the produced ARTIFACT (index.html gets
# embedded in a playable gallery), so this rubric only does LIGHT, STRUCTURAL
# scoring - it cannot judge if the page is pretty. It is fully hermetic and
# deterministic: pure bash + python token checks, NO headless browser, NO
# network, NO clock. Constant denominator: every check is predeclared, so a
# missing file scores every check 0 (never skipped).
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

# All structural/token checks are computed in one python pass that ALWAYS
# prints exactly one line per declared check (name<space>0|1<space>note),
# whether the file exists or not. This keeps the denominator constant for
# every submission (empty, partial, correct). The file is read
# case-insensitively and we are lenient about formatting (models vary), but
# we require the real elements the task calls for.
RES=$(WS="$WS" python3 - <<'PY' 2>&1
import os, re, sys

ws = os.environ["WS"]
path = os.path.join(ws, "index.html")

raw = ""
try:
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        raw = fh.read()
except Exception as e:
    print("READ_ERR", repr(e)[:80], file=sys.stderr)

low = raw.lower()
nbytes = len(raw.encode("utf-8", "replace"))

def emit(name, passed, note=""):
    note = str(note).replace("\\", "").replace('"', "'").replace("\n", " ").replace("\t", " ")
    print(name, 1 if passed else 0, note)

def has(*subs):
    # True if ALL substrings are present (case-insensitive)
    return all(s in low for s in subs)

def has_any(*subs):
    return any(s in low for s in subs)

# 1) non-trivial size: a real landing page is much bigger than a stub.
emit("size>=800", nbytes >= 800, "bytes=%d" % nbytes)

# 2) skeleton: <html> ... <body>. (A <script> is NOT required for a static
#    landing page; semantic structure is what matters here.)
emit("html_skeleton", has("<html") and has("<body"), "")

# 3) sticky nav: a <nav> element plus position:sticky or position:fixed CSS.
nav_el = "<nav" in low
sticky = has_any("position:sticky", "position: sticky", "position:fixed", "position: fixed")
emit("nav_sticky", nav_el and sticky, "nav=%s sticky=%s" % (nav_el, sticky))

# 4) hero heading: an <h1> (the headline) anywhere in the document.
emit("hero_heading", "<h1" in low, "")

# 5) CTA button: a <button> or an anchor/link styled as a button (class/role).
cta = ("<button" in low) or bool(re.search(r'class=["\'][^"\']*btn', low)) \
      or ('role="button"' in low) or has_any("cta", "call to action", "get started", "sign up", "buy now", "learn more")
emit("cta_button", cta, "")

# 6) multiple sections: a 3-card features section + footer means several
#    <section> blocks (or section + footer). Require >=2 <section> OR
#    (>=1 <section> and a <footer>).
n_section = len(re.findall(r"<section\b", low))
has_footer = "<footer" in low
emit("multi_sections", n_section >= 2 or (n_section >= 1 and has_footer),
     "sections=%d footer=%s" % (n_section, has_footer))

# 7) footer present.
emit("footer", has_footer, "")

# 8) three feature cards: look for a repeated card-ish class at least 3x,
#    or three feature/card mentions. Lenient on the exact class name.
card_hits = len(re.findall(r'class=["\'][^"\']*(?:card|feature)', low))
emit("three_cards", card_hits >= 3, "card_class_hits=%d" % card_hits)

# 9) responsive: a @media query (the hard signal that they handled mobile).
emit("responsive_media", "@media" in low, "")

# 10) modern layout: flexbox or grid.
layout = has_any("display:flex", "display: flex", "display:grid", "display: grid",
                 "flex-direction", "grid-template")
emit("flex_or_grid", layout, "")

# 11) tasteful CSS polish: gradient AND a hover state AND rounded corners.
gradient = has_any("linear-gradient", "radial-gradient", "conic-gradient")
hover = ":hover" in low
rounded = has_any("border-radius",)
emit("css_polish", gradient and hover and rounded,
     "gradient=%s hover=%s radius=%s" % (gradient, hover, rounded))

# 12) balanced-tags sanity (rough): <div count vs </div count not wildly off,
#     and <html> is closed. Showcase rubric only wants a sanity gate, not a
#     real parser.
opens = len(re.findall(r"<div\b", low))
closes = len(re.findall(r"</div>", low))
balanced = (abs(opens - closes) <= 2) and ("</html>" in low)
emit("tags_balanced", balanced, "div_open=%d div_close=%d html_closed=%s"
     % (opens, closes, "</html>" in low))
PY
)
echo "$RES" >&2

# file:index.html is scored in bash (constant regardless of python outcome).
add "file:index.html" "$file_ok" 10

# Fold each emitted structural line in at its declared weight. Because the
# python ALWAYS prints every declared check, the denominator never changes.
declare -A WEIGHT=(
  [size>=800]=10
  [html_skeleton]=15
  [nav_sticky]=10
  [hero_heading]=8
  [cta_button]=8
  [multi_sections]=10
  [footer]=4
  [three_cards]=8
  [responsive_media]=8
  [flex_or_grid]=8
  [css_polish]=5
  [tags_balanced]=6
)

declare -A SEEN
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  [[ "$name" == "READ_ERR" ]] && continue
  [[ -z "${WEIGHT[$name]:-}" ]] && continue
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  add "$name" "$pass" "${WEIGHT[$name]}" "$note"
  SEEN["$name"]=1
done < <(printf '%s\n' "$RES")

# Safety net: if the python crashed catastrophically (e.g. interpreter
# missing) so a declared check never printed, add it as a 0 so the
# denominator stays constant no matter what.
for n in "${!WEIGHT[@]}"; do
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
