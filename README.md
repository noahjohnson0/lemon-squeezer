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

**What works locally, on which hardware, for which job.**

lemon-squeezer has two tracks. Each track has one goal.

| | Benchmarks | Research |
|---|---|---|
| Goal | Say what works locally, on which hardware, for which job (coding agents, tool calling) | Find and report effects that are not already published |
| A claim is | A ranking or a recommendation with an interval, a cost and a speed | A new effect with an interval, replicated, after a related-work check |
| Novelty | Not required. The work has to be practical, reproducible and current | Required |
| Format | Study pages built from the run data in this repo | Papers. A line that is not ready is listed with its question and no numbers |
| Where | This repo and the site's home, `/studies/`, `/methods/`, `/data/` | The site's `/research/` page. The experiments are run in a separate lab repo |

The benchmarks hold the prompts and rubrics fixed and vary four things:

> **model** x **harness** x **config** x **venue**

Every run is scored by running the code it produced or by checking the state it left behind.

## Four venues

| | Local (4070) | Local (M4 Max) | Local (Mac Studio) | Cloud |
|---|---|---|---|---|
| Hardware | RTX 4070 Super, 12 GB | M4 Max, 48 GB unified | M5 Max, 128 GB unified (120 GB GPU limit) | rented on [OpenRouter](https://openrouter.ai) |
| Cost | electricity (~kWh) | electricity (~kWh) | electricity (~kWh) | API fees (~$/task) |
| Privacy | total, offline | total, offline | total, offline | none |
| Model ceiling | ~14-30B (quantized) | ~70B+ | ~120B MoE at Q4, 235B at 3-bit | 480B+ frontier-open |
| Engine | Ollama | Ollama | llama.cpp (`llama-server`) | provider |
| Benchmark | coding suite | coding suite | agentic tool calling | coding suite |
| Runner | `bin/eval-run` | `bin/eval-run --host m4max` | separate harness; rows in [`studio/`](studio/) | `bin/cloud-run` / `bin/cloud-matrix` |

On the coding suite it is the same agent, same tasks and same scoring for the 4070, the M4 Max and the cloud, so model-vs-model, harness-vs-harness and local-vs-cloud are honest comparisons there. (The M4 Max venue has 3 smoke runs so far; a real sweep is on the [roadmap](ROADMAP.md).) The **Mac Studio** runs a different benchmark: big local models as tool-calling agents on files, mail, messages and an intranet, scored on the end state. Its scores do not compare with the coding suite's. See [FINDINGS-STUDIO.md](FINDINGS-STUDIO.md).

## Current benchmark results

The site computes every number from `runs.jsonl` and `studio/summary.json` at build time, so the numbers are on the site and are not repeated here. The home page has the current picks per job and hardware, and these notes:

- llama.cpp's tool-call grammar accepts keys only in schema order. One tool listed an optional key late, and a model that wrote its keys in another order could not send that parameter.
- The tool-calling exploration found twelve harness bugs. The gaps between the top models were smaller than the effect of those bugs, and most paired model comparisons are too wide to call.
- MLX and llama.cpp ran gpt-oss-120b at the same throughput. The score gap is too wide to call. MLX returned empty replies on tool calls its parser could not read, and llama.cpp's grammar prevents those.
- Abliteration showed no cost on tool use for gpt-oss-120b. The interval is wide, so a small cost is not ruled out.
- The pi harness matched a purpose-built toolset with a strong model. With weak models it scored below aider, whose edit format avoids the tool calls that small models fail at.

Results that a reader would expect (code execution helps an agent, a newer model beats its predecessor) are in the study pages and are not headlined. Comparisons whose interval includes zero are listed as too wide to call. The tool-calling numbers are exploration until the final pass is done. Write-ups: [FINDINGS-STUDIO.md](FINDINGS-STUDIO.md), [FINDINGS-CLOUD.md](FINDINGS-CLOUD.md).

## How it works

Everything runs through one small agent, `bin/squeezer.py`: a ~250-line, dependency-free tool-calling loop (`read_file` / `write_file` / `list_files` / `run_bash`) that talks to any OpenAI-compatible endpoint. Point it at local Ollama or at OpenRouter; only the base URL and model change. It also recovers tool calls from models that emit them as plain text, so it drives local models that stricter harnesses reject.

> **On `squeezer` itself:** it is our *reference* harness (minimal, transparent, hackable), not a claimed best-in-class agent. The controlled cloud bake-off (same models, same evals, eight harnesses incl. aider, pi, cline, codex and claude-code; see [FINDINGS-CLOUD.md](FINDINGS-CLOUD.md)) has aider well ahead of squeezer on weak models and a tie on strong ones. A standard external benchmark to put these numbers on a common ruler is still queued (see [ROADMAP.md](ROADMAP.md)).

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

The arms under test live in [`configs/cloud-arms.json`](configs/cloud-arms.json) (currently 26 single models + 13 mixes). The cloud suite there is 39 tasks (port-scanner, the 40th, was dropped as environment-dependent), with a separate 10-task hard tier.

## Eval anatomy

Each eval is `evals/<name>/`: a `prompt.md` (the task), a `rubric.sh` (runs the produced code, prints `{checks, score_pct}`), and an optional `files/` of starter code. Rubrics weigh **runtime correctness** over structure: a program that looks right but returns wrong answers loses most of its points. The suite spans algorithms (dijkstra, huffman, regex-engine), numerics (kalman-filter, fft), systems (rate-limiter, lru-cache), and multi-file "read-an-existing-codebase-and-change-it" tasks (bug-fix a ledger library, add CLI subcommands, refactor, build a state machine from spec).

## Honesty

The results are only as good as the method, and we are explicit about the current limits (and the fixes, in [ROADMAP.md](ROADMAP.md)):

- **Rubric integrity (fixed 2026-06-15).** An adversarial review found 26 rubrics that could score a non-working stub at 100% (an import error dropped the behavioral checks and collapsed the denominator). All 26 were rewritten so every check always emits, and **all 2,894 affected runs were re-scored**; some scores correctly dropped. Details in [ROADMAP.md](ROADMAP.md#0-integrity-audit---2026-06-15-codex-adversarial-review).
- **Stats.** `cloud-report` aggregates per eval first (trials of one eval are correlated) and reports a cluster-bootstrap 95% CI; the dashboard ranks by means with low-coverage rows pulled toward the mean, so one lucky run can't top the table.
- **Sampling is not yet pinned by default** (`--temperature/--seed` exist; the next canonical sweep will use them), so older single-trial scores carry noise.
- **No sandbox yet.** The agent's `run_bash` could read a rubric mid-run (a contamination vector, not yet observed); real isolation needs a container. API keys are scrubbed from the agent shell.
- **Home-field bias.** Until a standard external benchmark (aider-polyglot / SWE-bench-lite) runs, treat "best on our suite" as exactly that.

## Repo map

```
bin/
  squeezer.py / squeezer_pipeline.py   # the agent + multi-model mixes
  eval-run                             # local runner (Ollama), GPU-locked + telemetry
  cloud-run / cloud-matrix             # cloud runner + budgeted parallel sweep
  cloud-report / energy-report         # leaderboard ($) + electricity (kWh)
  studio-pull / studio-summary         # Mac Studio tool-calling rows -> studio/summary.json
  studio-refresh [--pr]                # both, plus a PR, once the final pass lands
evals/<name>/        # prompt.md + rubric.sh (+ optional files/)
configs/cloud-arms.json   # the experiment design (models + mixes)
runs.jsonl           # one JSON per run, the source of truth
studio/rows/         # Mac Studio tool-calling rows, one JSON per task (separate benchmark)
dashboard-next/      # Next.js dashboard -> GitHub Pages (/ local, /cloud cloud)
ROADMAP.md           # where this is going
```

## Site

Live at [noahjohnson0.github.io/lemon-squeezer](https://noahjohnson0.github.io/lemon-squeezer/). The header has one tab per track.

- **Benchmarks.** The home page has the current picks, the notes above and the comparisons that are too wide to call. `/studies/` has one page per study (method, results with intervals, limitations, data). `/methods/` and `/data/` (sanitized downloads) belong to this track. Every number is computed at build time from `runs.jsonl` and `studio/summary.json` (`dashboard-next/src/lib/site-data.ts`).
- **Research.** `/research/` states the bar (related-work check, an effect with an interval, replication) and lists each line of work with its question and its status against the bar (`dashboard-next/src/lib/research.ts`). A line gets a paper page when it clears the bar. Until then the page states no result for it.

The old `/local`, `/cloud` and `/studio` URLs redirect to the matching study.

## License

MIT.
