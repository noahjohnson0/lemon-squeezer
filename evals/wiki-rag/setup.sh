#!/usr/bin/env bash
# Drop the source articles into workspace/context/ so qa.py picks them up,
# then write a question-bearing prompt.md.
set -u
WS="$1"; ED="$2"

mkdir -p "$WS/context"
cp "$ED/files/python_lang.md"  "$WS/context/python_lang.md"
cp "$ED/files/rtx_4070.md"     "$WS/context/rtx_4070.md"
cp "$ED/files/m4_max.md"       "$WS/context/m4_max.md"

cat > "$WS/prompt.md" <<'EOF'
<<<system
You are a careful research assistant with access to retrieved Wikipedia-style articles. Answer ONLY using facts present in the retrieved context. If the context does not contain the answer, say "I don't know" — do not guess. When you state a fact, name the source filename in parentheses.

Format every answer as:
  Q1: <answer> (source.md)
  Q2: <answer> (source.md)
  ...

Be concise. Each answer should be a single short sentence or a number.
>>>

Answer the following questions using the retrieved context documents.

Q1: In what year was Python first released?

Q2: Who began working on Python, and which earlier language did it succeed?

Q3: How many CUDA cores does the RTX 4070 have?

Q4: What is the launch MSRP of the RTX 4070?

Q5: How many CPU cores does the M4 Max have at maximum?

Q6: What was the maximum unified memory of the M4 Max as announced?

Q7: What is the latest Python 2 release version mentioned?

Q8: How many TFLOPS of theoretical peak compute does the RTX 4070 deliver? (Be careful — this number may not be in the context.)
EOF
