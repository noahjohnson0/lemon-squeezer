# Grid-down RAG findings — 2026-05-12

A session-long investigation of "can a local LLM on an RTX 4070 act as a
grid-down expert on practical questions (medical, 3D printing, radio,
electrical, space, water, food, comms, nav, tactics)." This file records
what was tested, what worked, what didn't, and where the real ceilings are.

## The setup

```
hardware       RTX 4070 12 GB VRAM (Windows) + Mac M4 orchestrator on LAN
inference      Ollama on the 4070
corpora        23 ZIM files served by kiwix-serve on port 8090, ~90 GB total
               Wikipedia (full), iFixit, Appropedia, WikiBooks, WikiMed,
               10 Stack Exchange dumps, LibreTexts (eng/med/workforce),
               Project Gutenberg LCC subsets (T/R/U/S)
eval           bench/gridown-50.jsonl — 51 practical factoid questions across
               11 domains, substring-scored against gold-answer aliases
```

## The pipeline that works

```
question → search_semantic
              └─ FTS5 multi-variant fan-out across all 23 corpora
                 (3 keyword variants per Q: full, longest, first-3 content words)
              └─ batch-embed candidates with nomic-embed-text (768-dim)
              └─ cosine rerank → top N
              └─ (optional) LLM listwise rerank → top 8
           → model reads snippets, writes_answer
```

Implemented harnesses (in order of increasing sophistication):
- `bin/librarian.py` — naive single-query FTS, baseline
- `bin/librarian-mq.py` — multi-query expansion (`search_multi`)
- `bin/librarian-sem.py` — FTS + cosine embedding rerank (`search_semantic`)
- `bin/librarian-rerank.py` — sem + LLM listwise rerank (cross-encoder-style)

## The numbers

### Stage A — gridown-50, single-pass (baseline)
| Model | Score | Wall/Q | Notes |
|---|---|---|---|
| qwen3:14b | **35.3%** | 25.8s | Best baseline |
| gemma4:e4b | 27.5% | 13.0s | Fast and underrated |
| command-r7b | 23.5% | 1.2s | 0 tool calls (Ollama tools broken); answers from training |
| gpt-oss:20b | 15.7% | 40.0s | Abstain-heavy |
| mistral-small:24b | 9.8% | 25.5s | Surprisingly weak |
| phi4:14b | 0.0% | 0.1s | Ollama "phi4 does not support tools" — invalid |

### Stage A-sem — semantic rerank (the +7.8pp lift)
| Model | Score | vs baseline | Wall/Q |
|---|---|---|---|
| qwen3:14b | **43.1%** | **+7.8pp** | 33.3s |
| gemma4:e4b | 35.3% | +7.8pp | 31.4s |
| qwen2.5:14b | 19.6% | (no baseline) | 26.4s |

Consistent +7.8pp on both models = real architectural win, not noise.

### Claude-as-judge re-grade on qwen3-sem
| Scoring method | Score |
|---|---|
| Substring match (gridown rubric) | 22/51 = **43.1%** |
| Claude semantic match | 33/51 = **64.7%** |
| Δ from scoring fairness | **+21.6pp** |

13 substring-misses were actually correct answers in different formatting:
Ohm's law "60 Ω" vs gold "60 ohms", "11.2 km/s" vs gold "11.186",
"299,792,458 m/s" vs gold (comma placement), Morse code in unicode chars,
NATO Delta cited correctly but regex wanted exact substring, etc.

2 substring-hits were actually wrong (gave homemade ORS values, not WHO).

### Stage A-rerank — LLM listwise rerank (predicted)
Smoke test on 3 known-failing Qs: 2 of 3 newly correct. Full sweep
running; expecting **~55-60% substring / ~70-75% Claude-judged** if the
2/3 fix rate holds.

## What didn't work (interventions tested and reverted)

| Intervention | Effect | Why it failed |
|---|---|---|
| Auto-inline top-1 article text | regression | Top-1 by cosine is often a BROAD overview article; injecting 6KB of overview text distracted the model into writing essays |
| HyDE rerank | regression | Hypothetical answers were too generic; averaging q+hyde embeddings pulled retrieval toward tangentially-related articles (chemistry essays for bleach Q) |
| Anti-abstention prompt alone | 1-of-3 fix, 2 regressions | Helps when retrieval is good; backfires when retrieval is off-topic (forced extraction from wrong articles) |
| `mxbai-embed-large` swap | failed at batch-API | Single-text embed works fine; batch call returns 400. Likely a per-batch token limit specific to mxbai's Ollama runtime |

## Failure mode analysis on qwen3-sem (the 18 wrong-by-Claude answers)

```
ABSTAIN-wrongly (8):  Model said "I don't know" but the fact was retrievable
  Q1 boil time, Q2 CDC elevation, Q6 charcoal dose, Q17 PLA Tg,
  Q18 layer height, Q27 14 AWG, Q31 LEO velocity, Q43 food pH

WRONG-FABRICATED (8): Confident-but-wrong values
  Q3 SODIS 5h (right: 6h), Q12 burns 10-15min (right: 20),
  Q14 PLA 230-240°C (right: 190-220), Q22 wrong calling freq,
  Q23 wrong HF distress, Q35 cyanide essay, Q41 NaCl essay, Q21 Hertz essay

WRONG-FROM-SNIPPET (2): Extracted wrong info from a real snippet
  Q9 WHO ORS gave homemade values, Q26 PV voltage was cut off
```

**Key insight**: failures split roughly 50/50 between under-confidence
(abstain when answer IS there) and over-confidence (fabricate when not).
A "cite-or-abstain" prompt — require quoting a snippet for any claim —
could address both failure modes, but adds verbosity.

## What's documented but we haven't tried

| Intervention | Expected lift | Cost | Risk |
|---|---|---|---|
| **LLM listwise rerank** (cross-encoder-style) | +15-30pp | 1 extra LLM call per Q (~10s) | ~2x wall time |
| BGE-reranker or MS-MARCO via llama.cpp | +15-30pp | install llama.cpp; run reranker server | engineering bigger |
| Dense embedding INDEX (skip FTS entirely) | +20-40pp | hours to embed Wikipedia + indexing layer | biggest engineering |
| Cite-or-abstain prompt | unknown, probably +3-5pp | prompt-only | low risk |
| Bigger model (command-r:35b w/ VRAM offload) | unknown | 60+ s/Q | very slow on 12GB VRAM |

LLM listwise rerank is the one we're testing tonight in `librarian-rerank.py`.

## Realistic ceilings on this hardware

| Setup | Honest expectation |
|---|---|
| Best tonight (qwen3:14b + librarian-rerank if it holds) | 55-65% substring / 70-80% Claude-judged |
| Best with serious engineering (dense index + cross-encoder + cite-or-abstain) | 75-85% Claude-judged |
| Frontier cloud (GPT-4 + industrial RAG, published) | ~80-85% on TriviaQA |
| Local 4070 + naive RAG, untouched | 25-35% |

100% is not achievable on this stack regardless of engineering. It's
not achievable on cloud frontier stacks either — the published cap
is ~85% on factoid retrieval at best.

## The Wikipedia infrastructure

Built but not yet committed beyond benchmark scripts:
- `/Users/noahjohnson0/refs/<corpus>/.lemon-zim.conf` — registers each
  ZIM as a queryable corpus pointing at kiwix-serve
- 23 corpora registered including `wikipedia-en` (the full 48GB ZIM)
- kiwix-serve on the 4070 at `192.168.0.117:8090` serves all 23 books
  with a single startup command via WMI (survives ssh session exit)
- Windows Firewall rule for TCP 8090 (Private/Domain profiles only)

## What's next (after this session)

1. Land the LLM-rerank sweep result; commit if it improves
2. Try cite-or-abstain prompt to address fabrications
3. Investigate dense-only retrieval (skip FTS): embed each corpus article,
   build SQLite-with-vector-extension index OR use ChromaDB locally,
   skip kiwix-serve for retrieval (keep it for fetching full article text)
4. Pull `bge-reranker-base` and use it via llama.cpp's reranker server
   (real cross-encoder, not LLM-listwise approximation)
5. Fix the mxbai batch-embed bug to enable the higher-quality embedder
6. Add cite-required scoring: model must cite a snippet path for each
   claim; rubric checks the cited article actually contains the claim
