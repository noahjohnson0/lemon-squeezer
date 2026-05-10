# 🍋 Findings

_249 runs · 26 evals · 7 harnesses · 10 models. Auto-generated._

## Harness scoreboard

| harness | avg | cells |
|---|---:|---:|
| `squeezer-critique` | **77.2** | 6 |
| `aider` | **75.4** | 142 |
| `squeezer-architect` | **60.2** | 12 |
| `squeezer-tdd` | **57.7** | 12 |
| `squeezer-verify` | **52.2** | 12 |
| `pi` | **45.1** | 31 |
| `squeezer` | **21.7** | 3 |

## Model scoreboard

| model | avg | cells |
|---|---:|---:|
| `qwen3:8b` | **88.7** | 3 |
| `qwen2.5:14b` | **86.8** | 6 |
| `gpt-oss:20b` | **84.1** | 35 |
| `qwen3-coder:30b-a3b-q4_K_M` | **79.3** | 52 |
| `llama3.1:8b` | **78.1** | 7 |
| `mistral-small:24b` | **73.9** | 24 |
| `qwen3:14b` | **60.1** | 59 |
| `devstral:24b` | **48.3** | 16 |
| `phi4:14b` | **11.6** | 8 |
| `granite3.3:8b` | **10.0** | 8 |

## Alchemy: multi-step vs single-pass

| eval | model | single-pass | multi-step | Δ |
|---|---|---:|---:|---:|
| `sql-injection-fix` | `qwen3:14b` | 65% | 85% | **+20** |
| `sql-injection-fix` | `gpt-oss:20b` | 85% | 100% | **+15** |
| `bug-fix` | `qwen3:14b` | 100% | 100% | **+0** |
| `dijkstra` | `qwen3:14b` | 100% | 100% | **+0** |
| `cli-tool` | `qwen3:14b` | 100% | 100% | **+0** |
| `bug-fix` | `qwen3-coder:30b-a3b-q4_K_M` | 100% | 100% | **+0** |
| `kepler-orbit` | `qwen3-coder:30b-a3b-q4_K_M` | 100% | 100% | **+0** |
| `sql-injection-fix` | `qwen3-coder:30b-a3b-q4_K_M` | 85% | 85% | **+0** |
| `dijkstra` | `qwen3-coder:30b-a3b-q4_K_M` | 100% | 100% | **+0** |
| `wifi-stats` | `qwen3:14b` | 81% | 78% | **-3** |
| `wifi-stats` | `qwen3-coder:30b-a3b-q4_K_M` | 91% | 83% | **-8** |
| `chem-balance` | `qwen3:14b` | 11% | 0% | **-11** |
| `chem-balance` | `qwen3-coder:30b-a3b-q4_K_M` | 29% | 0% | **-29** |
| `kepler-orbit` | `qwen3:14b` | 100% | 0% | **-100** |

_Across 14 (eval × model) pairs with both single-pass and multi-step: 2 improved with a pipeline. Mean delta = **-8.3 pts**._

