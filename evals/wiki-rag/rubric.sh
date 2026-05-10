#!/usr/bin/env bash
# Score the librarian on faithfulness:
#  - did it find the right fact?
#  - did it cite the correct source file?
#  - did it correctly say "I don't know" for the question whose answer isn't in context?
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

A="$WS/answer.txt"
add "file:answer.txt" "$([[ -f "$A" ]] && echo 1 || echo 0)" 5

if [[ -f "$A" ]]; then
  ans="$(cat "$A")"
  ans_lower="$(echo "$ans" | tr '[:upper:]' '[:lower:]')"

  # Q1: Python first released 1991
  echo "$ans" | grep -qE '\b1991\b' && add "q1_year" 1 8 || add "q1_year" 0 8
  echo "$ans_lower" | grep -qE 'python_lang|python lang' && add "q1_cite" 1 4 || add "q1_cite" 0 4

  # Q2: Guido van Rossum, ABC
  echo "$ans" | grep -qiE 'guido' && add "q2_who" 1 5 || add "q2_who" 0 5
  echo "$ans" | grep -qE '\bABC\b' && add "q2_predecessor" 1 5 || add "q2_predecessor" 0 5

  # Q3: 5888 CUDA cores
  echo "$ans" | grep -qE '\b5,?888\b' && add "q3_cuda" 1 8 || add "q3_cuda" 0 8
  echo "$ans_lower" | grep -qE 'rtx_4070|rtx 4070' && add "q3_cite" 1 3 || add "q3_cite" 0 3

  # Q4: $599 USD MSRP
  echo "$ans" | grep -qE '\$\s*599|599\s*USD|599\s*\$' && add "q4_price" 1 8 || add "q4_price" 0 8

  # Q5: 16 CPU cores max
  echo "$ans" | grep -qE '\b16\b.*\b[Cc][Pp][Uu]|\b16-core' && add "q5_cores" 1 8 || add "q5_cores" 0 8

  # Q6: 128 GB max unified memory
  echo "$ans" | grep -qiE '\b128 ?GB|128 ?gigabyte' && add "q6_mem" 1 8 || add "q6_mem" 0 8

  # Q7: Python 2.7.18
  echo "$ans" | grep -qE '\b2\.7\.18\b' && add "q7_py2_ver" 1 8 || add "q7_py2_ver" 0 8

  # Q8: TFLOPS isn't in context — model should abstain
  if echo "$ans_lower" | grep -qE "i don'?t know|don'?t know|not (in|provided|present)|cannot find|no information|isn'?t (in|mentioned|present)|context (does|doesn'?t)"; then
    add "q8_abstain_correctly" 1 15
  elif echo "$ans" | grep -qE '\b[0-9]+(\.[0-9]+)? *(?:TFLOP|TFLOPS|teraflop|teraflops)\b'; then
    add "q8_abstain_correctly" 0 15 "fabricated a TFLOPS number"
  else
    # Some other answer — partial credit if vaguely abstaining
    add "q8_abstain_correctly" 0 15 "did not clearly abstain"
  fi

  # Faithfulness: at least 4 of 7 fact-questions should cite a .md file (rough proxy)
  cites=$(echo "$ans" | grep -oE '[a-z_]+\.md' | sort -u | wc -l | tr -d ' ')
  (( cites >= 2 )) && add "cites_sources" 1 7 "found $cites distinct citations" || \
    add "cites_sources" 0 7 "only $cites citations"
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
