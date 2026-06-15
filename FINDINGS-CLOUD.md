# Findings: getting the most out of open-weight coding agents

What we have learned squeezing open-weight models as coding agents, holding prompts
and rubrics fixed and varying model x harness x venue. Every score comes from running
the produced code against a deterministic rubric. Numbers below are from the cloud
sweeps (tag `fable-hunt`, ~4,000 runs across 39 arms x 40 evals) plus a controlled
harness bake-off and a local 4070 quant check.

> **Integrity note (2026-06-15).** An adversarial review found that 26 rubrics could
> award 100% to a non-working stub (an import error silently dropped the behavioral
> checks, collapsing the denominator). All 26 were rewritten so every check always
> emits and the denominator is constant, and **all 2,894 affected runs were re-scored**
> against the fixed rubrics. The numbers here are post-fix. Some scores dropped
> (correctly). 95% CIs are a cluster bootstrap over evals; treat overlapping intervals
> as ties. See [ROADMAP.md](ROADMAP.md#0-integrity-audit---2026-06-15-codex-adversarial-review).

## Headline: the harness can matter more than the model

A controlled head-to-head (same model, same evals, same cloud endpoint, only the
harness changes), compared **only on the (eval, model) cells where both harnesses
ran** (the original bake-off was unpaired; this is the corrected paired view):

| model | squeezer (tool-calling) | aider (edit format) | gap |
|---|---:|---:|---:|
| qwen3-coder-30b | 7% | 76% | **+69** |
| llama-3.1-8b | 12% | 74% | **+62** |
| mistral-small-3.2 | 78% | 81% | +3 |
| gpt-oss-120b | 100% | 100% | 0 |
| deepseek-v4-flash | 100% | 100% | 0 |

Over the 38 paired cells, aider averages **79.7%** vs squeezer's **46.8%** (+32.9 pts,
aider wins 24, squeezer 5, ties 9). The pattern is the story: **the weaker the model,
the bigger the harness swing** (a 60+ point jump on the small models from identical
weights), while **strong models tie** - they barely need the harness. aider's
whole-file / diff edit format sidesteps the exact-match tool-calling failures that sink
small models under squeezer.

Consequence: **squeezer is our minimal *reference* harness, not the best agent.**
Any "best model" claim must name the harness. (Caveat: bake-off coverage is uneven per
model - qwen3-coder-30b has only 4 paired cells - and a standard external benchmark is
still queued; treat magnitudes as indicative, the direction as solid.)

## Cloud leaderboard: a tied cluster, not one winner

Under squeezer, ~100 runs per arm over all 40 evals. The top is a cluster whose
confidence intervals overlap (statistically tied), not a single champion:

| arm | harness | mean | 95% CI | $/task |
|---|---|---:|---:|---:|
| deepseek-v4-pro | single | 97.5% | 93-100 | $0.023 |
| deepseek-v4-flash | single | 97.0% | 92-100 | $0.0028 |
| verify:pro | mix | 96.8% | 92-100 | $0.043 |
| qwen3-max | single | 96.1% | 91-100 | $0.010 |
| arch:flash<-pro | mix | 96.0% | 91-99 | $0.0089 |
| arch:120b<-qwen-max | mix | 95.7% | 90-99 | $0.0038 |
| glm-5.1 | single | 95.3% | 89-100 | $0.016 |
| kimi-k2.7-code | single | 95.0% | 90-99 | $0.018 |
| **gpt-oss-120b** | single | 90.4% | 84-96 | **$0.0007** |

The honest takeaways:

- **Top is a tie.** ~8 arms sit inside overlapping CIs; "one model destroys the rest"
  is not supported. Rank by lower CI bound and they're a cluster.
- **Best bang for buck: `gpt-oss-120b`** at ~$0.0007/task (~1300 score per dollar), a
  handful of (overlapping-ish) points below the top.
- **Mixes do not clearly beat the best single.** The best mixes (verify:pro, arch:*)
  sit inside the top cluster but cost 5-60x more and run slower. Their real use is
  rescuing weak models, not raising the ceiling - and aider rescues weak models far
  more cheaply than a frontier-judged mix.
- **Reasoning models underperform** at agentic coding (deepseek-r1 well down), and
  "coding-specialist" models (codestral, devstral) did not beat strong generalists.

## Local vs cloud: quality transfers, with a small quant tax

Quality is venue-independent (same weights, same output), so we measure it in the
cloud. The one real difference is quantization: cloud serves higher precision than a
local q4 build. Measured on the 4070 (same 16-eval subset):

| model | local q4 (4070) | cloud (higher precision) |
|---|---:|---:|
| gpt-oss:20b | 72% | 77% |
| qwen3-coder:30b | 70% | 73% |

So local q4 runs about **3-5 points below** cloud precision, and the **ranking is
preserved**. Cloud quality is a reliable proxy for "what is best to run locally."

## Cost of testing: cloud vs local

| run the 40-eval suite once on one model | cost | wall time |
|---|---:|---:|
| cloud | $0.054 | ~1.6 min (parallel) |
| local 4070 | $0.027 electricity | ~43 min (serial) |

Local electricity is ~2x cheaper per run, but both are pennies, and the cloud is ~27x
faster because it parallelizes. For *testing*, the cloud wins; the local GPU's real job
is confirming a model runs/fits and measuring speed and watts. (See `bin/energy-report`.)

## What this means for "what should I run?"

- **On your GPU:** pick the best-scoring open model that fits your VRAM at q4
  (recommender on the dashboard, by VRAM tier). Use **aider**, not a bare tool-calling
  loop, especially below ~30B.
- **In the cloud:** `gpt-oss-120b` for value, or the top tied cluster
  (deepseek-v4-pro/flash, qwen3-max, glm-5.1, kimi) for maximum quality at pennies/task.
- Either way it is open weights, and the harness choice can matter more than the model.

## Honesty / limits

- **Rubric integrity** was the big one (see the integrity note above): fixed and
  re-scored. Robustness follow-up: a few rubrics still emit notes that can corrupt the
  JSON breakdown on edge-case outputs; the *score* is always recovered, but the
  per-check drawer may be missing for those runs.
- **Sampling**: current sweeps use provider-default sampling; pinned temperature+seed
  is now wired (`--temperature/--seed`) and the next canonical sweep will use it.
- **Home-field bias**: scores are on our suite, which still leans algorithmic; a
  standard external benchmark (aider-polyglot / SWE-bench-lite) is queued.
- **No sandbox yet**: the agent's `run_bash` could read a rubric mid-run (contamination
  vector, not yet observed); real isolation needs a container. API keys are scrubbed
  from the agent shell.
- **Bake-off coverage** is uneven per model and squeezer-vs-aider only so far; pi and
  more models are next.

*Reproduce: `bin/cloud-report --by-eval`, `bin/bakeoff-report --tag bakeoff`,
`bin/cloud-rescore`, `bin/energy-report`. Live:
the [/cloud dashboard](https://noahjohnson0.github.io/lemon-squeezer/cloud).*
