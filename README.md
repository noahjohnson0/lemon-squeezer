<table border="0" cellspacing="0" cellpadding="0">
<tr>
<td width="220" valign="middle">
<picture>
<source media="(prefers-color-scheme: dark)" srcset="docs/assets/logo-dark.png">
<img src="docs/assets/logo-light.png" alt="lemon-squeezer" width="200">
</picture>
</td>
<td valign="middle"><h1>L&nbsp;E&nbsp;M&nbsp;O&nbsp;N &nbsp; S&nbsp;Q&nbsp;U&nbsp;E&nbsp;E&nbsp;Z&nbsp;E&nbsp;R</h1></td>
</tr>
</table>

**How much can you squeeze out of an LLM?**

A reproducible study of what actually makes a language model *finish real coding work*. We hold the prompts and rubrics fixed and vary the four things you actually control:

> **model** x **harness** x **config** x **venue**

...and we score every run by *running the code it produced*, not by vibes. The point is the squeeze: the most useful work per dollar, per watt, and per gigabyte of VRAM.

## Three venues, one benchmark

| | Local (4070) | Local (M4 Max) | Cloud |
|---|---|---|---|
| Hardware | RTX 4070 Super, 12 GB | M4 Max, 48 GB unified | rented on [OpenRouter](https://openrouter.ai) |
| Cost | electricity (~kWh) | electricity (~kWh) | API fees (~$/task) |
| Privacy | total, offline | total, offline | none |
| Model ceiling | ~14-30B (quantized) | ~70B+ | 480B+ frontier-open |
| Runner | `bin/eval-run` | `bin/eval-run --host m4max` | `bin/cloud-run` / `bin/cloud-matrix` |

Same agent, same tasks, same scoring across all three, so model-vs-model, harness-vs-harness, and local-vs-cloud are honest comparisons. (The M4 Max venue is on the [roadmap](ROADMAP.md), not yet run.)

## What we have found so far

These are real but **early**, and we are deliberate about not overclaiming (see *Honesty* below).

- **The harness can matter as much as the model.** Same `qwen3:14b` on `bug-fix`: 27% through one harness, 100% through another (whole-file rewrites dodge the failure mode that breaks exact-match editing on small models). A weak model with the right harness can beat a strong model with the wrong one.
- **For the cloud "which open model" question:** a cluster of cheap open models (deepseek-v4-flash, gpt-oss-120b, kimi, qwen3-max, glm-5.1) lands in the high-90s on our suite, and the cheapest of them, `gpt-oss-120b`, gets ~95% for about **$0.0005 per task**. Multi-model *mixes* mostly do not beat the best single model; they are a **weak-model rescue kit** (a critic loop pulls a 69% model up to ~94%). Full writeup: [FINDINGS-CLOUD.md](FINDINGS-CLOUD.md).
- **Reasoning models underperform at agentic coding** here, and "coding-specialist" models did not beat strong generalists.

## How it works

Everything runs through one small agent, `bin/squeezer.py`: a ~250-line, dependency-free tool-calling loop (`read_file` / `write_file` / `list_files` / `run_bash`) that talks to any OpenAI-compatible endpoint. Point it at local Ollama or at OpenRouter; only the base URL and model change. It also recovers tool calls from models that emit them as plain text, so it drives local models that stricter harnesses reject.

> **On `squeezer` itself:** it is our *reference* harness (minimal, transparent, hackable), not a claimed best-in-class agent. In our local head-to-heads aider currently scores higher. Settling "is squeezer actually good?" needs a proper harness bake-off against aider / pi / others on identical models and a standard external benchmark. That experiment is queued (see [ROADMAP.md](ROADMAP.md)).

```
        prompt.md ──► squeezer agent ──► workspace/ ──► rubric.sh ──► score%
                          (any model, any venue)              runs.jsonl
```

A **mix** (`bin/squeezer_pipeline.py`) wires several models over one workspace: a frontier model plans, a cheap one implements (architect); draft, critique, refine; ensemble-and-judge; or write-tests-and-self-correct (verify).

### Run one task

```bash
# Local, on the 4070:
bin/eval-run aider bug-fix qwen2.5-coder:14b baseline

# Cloud, one open model:
bin/cloud-run dijkstra deepseek/deepseek-v4-pro

# Cloud, a multi-model mix (frontier plans, cheap model implements):
bin/cloud-run dijkstra --pipeline architect \
    --primary-model qwen/qwen3-coder-30b-a3b-instruct \
    --architect-model deepseek/deepseek-v4-pro
```

### Run the whole experiment

```bash
bin/cloud-matrix --trials 4 --budget 80 --concurrency 24   # all arms x suite, budgeted + parallel
bin/cloud-report --tag fable-hunt --by-eval                # leaderboard: score, $/task, score-per-$
bin/energy-report --watts 250 --price 0.15 --by-model      # local electricity: kWh + cost
```

The arms under test live in [`configs/cloud-arms.json`](configs/cloud-arms.json) (currently 26 single models + 13 mixes). The eval suite is 40 tasks and growing.

## Eval anatomy

Each eval is `evals/<name>/`: a `prompt.md` (the task), a `rubric.sh` (runs the produced code, prints `{checks, score_pct}`), and an optional `files/` of starter code. Rubrics weigh **runtime correctness** over structure: a program that looks right but returns wrong answers loses most of its points. The suite spans algorithms (dijkstra, huffman, regex-engine), numerics (kalman-filter, fft), systems (rate-limiter, lru-cache), and multi-file "read-an-existing-codebase-and-change-it" tasks (bug-fix a ledger library, add CLI subcommands, refactor, build a state machine from spec).

## Honesty

The results are only as good as the method, and we are explicit about the current limits (and the fixes, in [ROADMAP.md](ROADMAP.md)):

- **Sampling is not yet pinned** (no fixed temperature/seed), so single-trial scores carry noise.
- **Means hide trial counts.** The live dashboard now shrinks low-n arms so a one-run 100% cannot outrank a 57-run 98%; confidence intervals are coming to the reports.
- **Home-field bias.** Until the harness bake-off and a standard external benchmark run, treat "best on our suite" as exactly that.

## Repo map

```
bin/
  squeezer.py / squeezer_pipeline.py   # the agent + multi-model mixes
  eval-run                             # local runner (Ollama), GPU-locked + telemetry
  cloud-run / cloud-matrix             # cloud runner + budgeted parallel sweep
  cloud-report / energy-report         # leaderboard ($) + electricity (kWh)
evals/<name>/        # prompt.md + rubric.sh (+ optional files/)
configs/cloud-arms.json   # the experiment design (models + mixes)
runs.jsonl           # one JSON per run, the source of truth
dashboard-next/      # Next.js dashboard -> GitHub Pages (/ local, /cloud cloud)
ROADMAP.md           # where this is going
```

## Dashboard

Live at [noahjohnson0.github.io/lemon-squeezer](https://noahjohnson0.github.io/lemon-squeezer/). Reads `runs.jsonl` directly: **/** is the local leaderboard, **/cloud** is the open-model and local-vs-cloud view.

## License

MIT.
