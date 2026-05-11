#!/usr/bin/env bash
# wiki-full rubric — score a librarian-style RAG agent on full English Wikipedia.
#
# Scoring matches wiki-rag-tool's two-axis pattern:
#   - did it find the right fact (answer substring)?
#   - did it cite a plausible article slug?
#   - did it abstain on Q8 (deliberately not in Wikipedia)?
#   - did it actually USE the tools (≥1 search, ≥1 read per question expected)?
#
# Rubric gotcha (CLAUDE.md #1): the rubric's STDOUT becomes score.json.
# All diagnostic prints in this file are routed to stderr (>&2) — keep it
# that way. The final JSON is emitted inside one printf block at the end.
set -u
WS="${1:?workspace}"

declare -a checks
add() {
  # name, pass(0/1), weight, optional note. Sanitize the note to avoid the
  # JSON-escape bug from CLAUDE.md #2 — strip backslashes, swap " for '.
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  note="${note//\\/}"
  note="${note//\"/\'}"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

A="$WS/answer.txt"
add "file:answer.txt" "$([[ -f "$A" ]] && echo 1 || echo 0)" 5

if [[ -f "$A" ]]; then
  ans="$(cat "$A")"
  ans_lower="$(echo "$ans" | tr '[:upper:]' '[:lower:]')"
  # Wikipedia renders some numerics with SI thin-spaces inside the digits
  # (e.g. "9.806 65", "5 888 cores"); models faithfully copy that. Strip
  # whitespace and U+202F/U+00A0 so the numeric regexes can match.
  ans_packed="$(echo "$ans" | python3 -c 'import sys; s=sys.stdin.read(); print("".join(c for c in s if not c.isspace() and c not in "   "))')"

  # ---- Q1: standard gravity = 9.80665 m/s²  (article: Standard_gravity) ----
  echo "$ans_packed" | grep -qE '9\.80665' \
    && add "q1_value" 1 8 \
    || add "q1_value" 0 8
  echo "$ans" | grep -qiE 'standard[_ ]gravity' \
    && add "q1_cite" 1 4 \
    || add "q1_cite" 0 4

  # ---- Q2: element 74 = tungsten  (article: Tungsten) ----
  echo "$ans_lower" | grep -qE '\btungsten\b' \
    && add "q2_element" 1 8 \
    || add "q2_element" 0 8
  echo "$ans" | grep -qE '\bTungsten\b' \
    && add "q2_cite" 1 4 \
    || add "q2_cite" 0 4

  # ---- Q3: C6H5CH3 = methylbenzene / toluene  (article: Toluene) ----
  echo "$ans_lower" | grep -qE 'methylbenzene' \
    && add "q3_iupac" 1 8 \
    || add "q3_iupac" 0 8
  echo "$ans" | grep -qiE 'toluene' \
    && add "q3_cite" 1 4 \
    || add "q3_cite" 0 4

  # ---- Q4: Treaty of Tordesillas = 1494  (article: Treaty_of_Tordesillas) ----
  echo "$ans_packed" | grep -qE '1494' \
    && add "q4_year" 1 8 \
    || add "q4_year" 0 8
  echo "$ans" | grep -qiE 'tordesillas' \
    && add "q4_cite" 1 4 \
    || add "q4_cite" 0 4

  # ---- Q5: Master and Margarita = Bulgakov  (article: The_Master_and_Margarita) ----
  echo "$ans" | grep -qiE 'bulgakov' \
    && add "q5_author" 1 8 \
    || add "q5_author" 0 8
  echo "$ans" | grep -qiE 'master[_ ]and[_ ]margarita' \
    && add "q5_cite" 1 4 \
    || add "q5_cite" 0 4

  # ---- Q6: Krakatoa eruption = 1883  (article: 1883_eruption_of_Krakatoa) ----
  echo "$ans_packed" | grep -qE '1883' \
    && add "q6_year" 1 8 \
    || add "q6_year" 0 8
  echo "$ans" | grep -qiE 'krakatoa' \
    && add "q6_cite" 1 4 \
    || add "q6_cite" 0 4

  # ---- Q7: cobalt-60 half-life ~5.27 years  (article: Cobalt-60) ----
  # Accept 5.27, 5.2714, or 5.272 — common roundings in physics textbooks.
  echo "$ans_packed" | grep -qE '5\.(27|2714|272)' \
    && add "q7_halflife" 1 8 \
    || add "q7_halflife" 0 8
  echo "$ans" | grep -qiE 'cobalt[-_ ]?60' \
    && add "q7_cite" 1 4 \
    || add "q7_cite" 0 4

  # ---- Q8: not in Wikipedia — model must abstain ----
  if echo "$ans_lower" | grep -qE "i don'?t know|don'?t know|not (in|provided|present|found)|cannot find|no information|isn'?t (in|mentioned|present)|wikipedia (does|doesn'?t)|not (available|mentioned)"; then
    add "q8_abstain_correctly" 1 12
  elif echo "$ans" | grep -qE 'Q8:[^(]*[0-9]\.[0-9]+'; then
    add "q8_abstain_correctly" 0 12 "fabricated a GPA number"
  else
    add "q8_abstain_correctly" 0 12 "did not clearly abstain"
  fi

  # ---- distinct citations: >=4 different article slugs across answers ----
  # Slug-shape is word chars + underscores inside parens; filter generics.
  cites=$(echo "$ans" | grep -oE '\([A-Z][A-Za-z0-9_-]+\)' | sort -u | wc -l | tr -d ' ')
  if (( cites >= 4 )); then
    add "distinct_citations" 1 5 "found $cites distinct citations"
  else
    add "distinct_citations" 0 5 "only $cites distinct citations"
  fi
fi

# ---- Retrieval-tool usage from the librarian trace (run_dir is one up) ----
RUN_DIR="$(dirname "$WS")"
TRACE="$RUN_DIR/librarian-trace.jsonl"
if [[ -f "$TRACE" ]]; then
  n_search=$(grep -c '"tool": "search_local"' "$TRACE" 2>/dev/null || echo 0)
  n_read=$(grep -c '"tool": "read_local"'   "$TRACE" 2>/dev/null || echo 0)
  if (( n_search >= 4 )); then
    add "used_search_tool" 1 8 "search_local x$n_search"
  else
    add "used_search_tool" 0 8 "only $n_search search calls"
  fi
  if (( n_read >= 3 )); then
    add "used_read_tool" 1 6 "read_local x$n_read"
  else
    add "used_read_tool" 0 6 "only $n_read read calls"
  fi
else
  # Trace file missing — both retrieval checks fail, but keep the denominator
  # constant (CLAUDE.md #4: always `add` every check).
  add "used_search_tool" 0 8 "no trace file"
  add "used_read_tool"   0 6 "no trace file"
fi

# ---- Emit score.json (this is the ONLY thing this rubric writes to stdout) ----
total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in ${checks[@]+"${checks[@]}"}; do
    IFS=$'\t' read -r name pass weight note <<<"$c"
    total=$((total+weight)); [[ "$pass" == "1" ]] && gained=$((gained+weight))
    [[ $first -eq 0 ]] && printf ',\n'
    printf '    {"name":"%s","pass":%s,"weight":%s,"note":"%s"}' \
      "$name" "$pass" "$weight" "$note"
    first=0
  done
  printf '\n  ],\n'
  pct=0; [[ $total -gt 0 ]] && pct=$(( (gained * 100) / total ))
  printf '  "gained": %s,\n  "total": %s,\n  "score_pct": %s\n}\n' \
    "$gained" "$total" "$pct"
}
