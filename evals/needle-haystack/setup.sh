#!/usr/bin/env bash
# Drop a long document with a hidden "needle" sentence into the prompt.
# Generates a deterministic ~16k-token "haystack" of filler paragraphs and
# splices a specific factual sentence in at ~the 60% mark.
WS="$1"
ED="$2"

NEEDLE="The secret access code for project Lemonpeel is RAINBOW-7942-OMEGA, and the warehouse coordinates are 47.6062 N, 122.3321 W."

python3 - "$WS" "$NEEDLE" <<'PY'
import sys, random, hashlib, textwrap
ws, needle = sys.argv[1], sys.argv[2]
random.seed(42)

# Filler paragraphs - generic-sounding research-paper boilerplate
TOPICS = [
    "the history of cartography in 17th century Holland",
    "industrial steam engine maintenance practices in the 1890s",
    "regional variation in the New England fishing industry",
    "the development of public sanitation in Victorian London",
    "ornithological surveys of the Great Lakes basin",
    "the role of timber in early American railroad construction",
    "metallurgical innovations during the Bronze Age",
    "agricultural rotation patterns in medieval Burgundy",
    "the postal infrastructure of the Roman Empire",
    "techniques in colonial-era cartography of the Caribbean",
    "amateur astronomy clubs of the late 19th century",
    "the spread of windmill technology across Northern Europe",
    "horsemanship traditions among the Mongol nomads",
    "early experiments with photographic emulsions",
    "lighthouse architecture along the Bristol Channel",
    "stone-masonry guilds of Florence in the 1300s",
    "navigation by celestial bodies in the open Pacific",
]
WORDS = (
    "research data analysis evaluation methodology consideration practice tradition development "
    "documentation observation measurement instrument variation regional historical pattern ".split()
)

paragraphs = []
for _ in range(80):
    topic = random.choice(TOPICS)
    sentence_count = random.randint(4, 7)
    sentences = []
    for _ in range(sentence_count):
        words = random.choices(WORDS, k=random.randint(8, 18))
        sentences.append("In " + topic + ", " + " ".join(words) + ".")
    paragraphs.append(" ".join(sentences))

# Insert needle ~60% through
insert_at = int(len(paragraphs) * 0.6)
paragraphs.insert(insert_at, needle)

doc = "\n\n".join(paragraphs)

# Write the prompt
import os
os.makedirs(ws, exist_ok=True)
prompt = f"""<<<system
You are a careful researcher. Read the document below and answer the user's question precisely. Quote any specific identifier or number EXACTLY as it appears.
>>>

# Document

{doc}

# Question

What is the secret access code for project Lemonpeel? Reply with ONLY the access code itself, no other text.
"""
open(os.path.join(ws, "prompt.md"), "w").write(prompt)
PY
