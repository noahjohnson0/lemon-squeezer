# 🍋 Lemon-Squeezer — Findings

Auto-generated from `runs.jsonl`. 207 runs, 26 evals, 7 harnesses, 9 models. Last updated by the build.

> See `dashboard-next/public/findings.md` for the live-rebuilt version that the dashboard renders. This top-level copy is the human-readable snapshot.

## Headline

**The harness matters more than the model.** Same `qwen3:14b`, on the same `bug-fix` eval, scores **27%** through `pi` and **100%** through `aider`. Pi's exact-string-match edit format trips up small models that hallucinate file contents; aider's whole-file rewrite format sidesteps the failure. We've reproduced this gap on every weak-spot eval we've built.

## Harness scoreboard

Average best score across all (eval × model) cells the harness has played:

| harness | avg | cells |
|---|---:|---:|
| `squeezer-critique` | **77.2** | 6 |
| `aider` | **75.0** | 115 |
| `squeezer-architect` | **58.1** | 9 |
| `squeezer-tdd` | **57.7** | 12 |
| `squeezer-verify` | **52.2** | 12 |
| `pi` | **45.1** | 31 |
| `squeezer` | **32.5** | 2 |

## Model scoreboard

Average best score across all (eval × harness) cells the model has played:

| model | avg | cells |
|---|---:|---:|
| `qwen3:8b` | **88.7** | 3 |
| `qwen2.5:14b` | **86.8** | 6 |
| `gpt-oss:20b` | **83.6** | 34 |
| `qwen3-coder:30b-a3b-q4_K_M` | **79.7** | 48 |
| `llama3.1:8b` | **78.1** | 7 |
| `qwen3:14b` | **60.5** | 57 |
| `devstral:24b` | **48.3** | 16 |
| `phi4:14b` | **11.6** | 8 |
| `granite3.3:8b` | **10.0** | 8 |

## Multi-step pipelines vs single-pass

Does running a draft → critique → refine pipeline beat just letting the model take one swing at it? Sometimes — on hard evals. Almost never on easy ones (those are already at 100%, no upside) and occasionally hurts (the critique step can over-polish a wrong answer instead of catching the root cause).

| eval | model | single-pass | multi-step | Δ |
|---|---|---:|---:|---:|
| `sql-injection-fix` | `qwen3:14b` | 65% | 85% | **+20** |
| `sql-injection-fix` | `gpt-oss:20b` | 85% | 100% | **+15** |
| `sql-injection-fix` | `qwen3-coder:30b-a3b-q4_K_M` | 85% | 85% | **+0** |
| `cli-tool` | `qwen3:14b` | 100% | 100% | **+0** |
| `bug-fix` | `qwen3-coder:30b-a3b-q4_K_M` | 100% | 100% | **+0** |
| `bug-fix` | `qwen3:14b` | 100% | 100% | **+0** |
| `dijkstra` | `qwen3-coder:30b-a3b-q4_K_M` | 100% | 100% | **+0** |
| `dijkstra` | `qwen3:14b` | 100% | 100% | **+0** |
| `wifi-stats` | `qwen3:14b` | 81% | 78% | **-3** |
| `wifi-stats` | `qwen3-coder:30b-a3b-q4_K_M` | 91% | 83% | **-8** |
| `chem-balance` | `qwen3:14b` | 11% | 0% | **-11** |
| `chem-balance` | `qwen3-coder:30b-a3b-q4_K_M` | 29% | 0% | **-29** |

_12 (eval × model) pairs with both single-pass AND multi-step results. 2 improved with a pipeline. Mean delta = **-1.3 points**._

## Coverage

- **24/26** evals where SOME combo hit 100%
- **25/26** evals where SOME combo hit ≥80%
- **26/26** evals where SOME combo hit ≥50%
- **0** evals nothing has cracked 50% on yet
