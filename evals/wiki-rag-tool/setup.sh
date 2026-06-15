#!/usr/bin/env bash
# wiki-rag-tool - like wiki-rag but the agent has to RETRIEVE the docs itself
# rather than receiving them in the system prompt. Tests retrieval skill.
set -u
WS="$1"; ED="$2"

# Drop the source articles into workspace/context/ so the librarian harness
# auto-builds an FTS5 index over them. The agent will have to use search_local
# to find each fact.
mkdir -p "$WS/context"
cp "$ED/files/python_lang.md"  "$WS/context/python_lang.md"
cp "$ED/files/rtx_4070.md"     "$WS/context/rtx_4070.md"
cp "$ED/files/m4_max.md"       "$WS/context/m4_max.md"

cat > "$WS/prompt.md" <<'EOF'
You are a research librarian with access to a local 'context' corpus of three
Wikipedia-style articles. Use search_local (and read_local if needed) to find
the answers. Do NOT guess - if a fact is not in the corpus, say so.

Cite the source filename in parentheses for each fact.

Answer the following questions, then call write_answer ONCE with the complete
formatted reply:

Q1: In what year was Python first released?
Q2: Who began working on Python, and which earlier language did it succeed?
Q3: How many CUDA cores does the RTX 4070 have?
Q4: What is the launch MSRP of the RTX 4070?
Q5: How many CPU cores does the M4 Max have at maximum?
Q6: What was the maximum unified memory of the M4 Max as announced?
Q7: What is the latest Python 2 release version mentioned?
Q8: How many TFLOPS of theoretical peak compute does the RTX 4070 deliver? (Be careful - this number may not be in the corpus.)

Format every answer as:
  Q1: <answer> (source.md)
  Q2: <answer> (source.md)
  ...
EOF
