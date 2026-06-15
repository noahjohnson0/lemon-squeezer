# Findings: getting the most out of open-weight coding agents

What we have learned squeezing open-weight models as coding agents, holding prompts
and rubrics fixed and varying model x harness x venue. Scored by running the
produced code. Numbers below are from the cloud sweeps (tag `fable-hunt`, ~3000
runs across 39 arms x 40 evals) plus a controlled harness bake-off and a local
4070 quant check. Confidence intervals are 95% on the mean; treat overlapping
intervals as ties.

## Headline: the harness matters more than the model

A controlled head-to-head (same model, same evals, same cloud endpoint, only the
harness changes) is the clearest result we have:

| model | squeezer (tool-calling) | aider (edit format) | gap |
|---|---:|---:|---:|
| llama-3.1-8b | 23% | 77% | **+54** |
| qwen3-coder-30b | 73% | 98% | +25 |
| mistral-small-3.2 | 72% | 87% | +15 |
| gpt-oss-120b | 93% | 100% | +7 |
| glm-4.7 | 93% | 100% | +7 |
| deepseek-v4-flash | 97% | 100% | +3 |

aider beats squeezer on every model, and **the weaker the model, the bigger the
harness swing** (a 54-point jump on llama-3.1-8b from identical weights). Strong
models need little harness; weak models are rescued by a good one. aider's
whole-file / diff edit format sidesteps the exact-match tool-calling failures that
sink small models under squeezer.

Consequence: **squeezer is our minimal *reference* harness, not the best agent.**
Any "best model" claim must name the harness, and the best results come from the
best harness, not from squeezer.

## Cloud leaderboard: a tied cluster, not one winner

Under squeezer, with n=84 per arm, the top is a cluster whose confidence intervals
overlap (so they are statistically tied), not a single champion:

| arm | mean | 95% CI | $/task |
|---|---:|---:|---:|
| deepseek-v4-flash | 97% | 94-100 | $0.0027 |
| glm-5.1 | 97% | 94-100 | $0.016 |
| verify:pro (mix) | 96% | 93-100 | $0.044 |
| deepseek-v4-pro | 96% | 93-100 | $0.024 |
| arch:120b<-qwen-max (mix) | 96% | 93-99 | $0.004 |
| kimi-k2.7-code | 96% | 92-100 | $0.017 |
| **gpt-oss-120b** | 93% | 88-98 | **$0.0007** |

The earlier "deepseek-v4-flash 100% destroyer" framing overstated precision: it is
one of ~8 arms that are tied. The honest takeaways:

- **Best bang for buck: `gpt-oss-120b`** at ~$0.0007/task (1400+ score per dollar),
  within a few (overlapping) points of the top.
- **Mixes do not clearly beat the best single.** The best mixes (verify:pro,
  arch:120b) sit inside the top cluster but cost 5-60x more and run slower. Their
  real use is rescuing weak models, not raising the ceiling (and aider rescues
  weak models far more cheaply than a frontier-judged mix does).
- **Reasoning models underperform** at agentic coding (deepseek-r1 well down the
  board), and "coding-specialist" models (codestral, devstral) did not beat strong
  generalists.

## Local vs cloud: quality transfers, with a small quant tax

Quality is venue-independent (same weights, same output), so we measure it in the
cloud. The one real difference is quantization: cloud serves higher precision than
a local q4 build. Measured on the 4070 (same 16-eval suite):

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

Local electricity is ~2x cheaper per run, but both are pennies, and the cloud is
~27x faster because it parallelizes. For *testing*, the cloud wins; the local GPU's
real job is confirming a model runs/fits and measuring speed and watts. (See
`bin/energy-report`.)

## What this means for "what should I run?"

- **On your GPU:** pick the best-scoring open model that fits your VRAM at q4
  (recommender on the dashboard, by VRAM tier). Use **aider**, not a bare
  tool-calling loop, especially below ~30B.
- **In the cloud:** `gpt-oss-120b` for value, or the top tied cluster
  (deepseek-v4-flash, glm-5.1, kimi, qwen3-max) for maximum quality at pennies/task.
- Either way it is open weights, and the harness choice can matter more than the
  model.

## Honesty / limits

- Current sweeps use provider-default sampling; pinned temperature+seed is now
  available (`--temperature/--seed`) and the next canonical sweep will use it.
- Scores are on our suite, which still leans algorithmic; a standard external
  benchmark (aider-polyglot / SWE-bench-lite) is queued to check home-field bias.
- The bake-off so far covers 6 models x squeezer/aider; pi and more models are next.

*Reproduce: `bin/cloud-matrix`, `bin/cloud-report --by-eval`, `bin/energy-report`.
Live: the [/cloud dashboard](https://noahjohnson0.github.io/lemon-squeezer/cloud).*
