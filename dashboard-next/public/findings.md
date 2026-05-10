# 🍋 Findings

_200 runs · 26 evals · 7 harnesses · 9 models. Auto-generated._

## Harness scoreboard

| harness | avg | cells |
|---|---:|---:|
| `squeezer-critique` | **77.2** | 6 |
| `aider` | **75.0** | 115 |
| `squeezer-architect` | **65.0** | 2 |
| `squeezer-tdd` | **57.7** | 12 |
| `squeezer-verify` | **52.2** | 12 |
| `pi` | **45.1** | 31 |
| `squeezer` | **32.5** | 2 |

## Model scoreboard

| model | avg | cells |
|---|---:|---:|
| `qwen3:8b` | **88.7** | 3 |
| `qwen2.5:14b` | **86.8** | 6 |
| `gpt-oss:20b` | **83.6** | 34 |
| `qwen3-coder:30b-a3b-q4_K_M` | **79.6** | 45 |
| `llama3.1:8b` | **78.1** | 7 |
| `qwen3:14b` | **62.2** | 53 |
| `devstral:24b` | **48.3** | 16 |
| `phi4:14b` | **11.6** | 8 |
| `granite3.3:8b` | **10.0** | 8 |

## Alchemy: multi-step vs single-pass

| eval | model | single-pass | multi-step | Δ |
|---|---|---:|---:|---:|
| `sql-injection-fix` | `qwen3:14b` | 65% | 85% | **+20** |
| `sql-injection-fix` | `gpt-oss:20b` | 85% | 100% | **+15** |
| `sql-injection-fix` | `qwen3-coder:30b-a3b-q4_K_M` | 85% | 85% | **+0** |
| `cli-tool` | `qwen3:14b` | 100% | 100% | **+0** |
| `bug-fix` | `qwen3-coder:30b-a3b-q4_K_M` | 100% | 100% | **+0** |
| `bug-fix` | `qwen3:14b` | 100% | 100% | **+0** |
| `dijkstra` | `qwen3-coder:30b-a3b-q4_K_M` | 100% | 100% | **+0** |
| `wifi-stats` | `qwen3:14b` | 81% | 78% | **-3** |
| `wifi-stats` | `qwen3-coder:30b-a3b-q4_K_M` | 91% | 83% | **-8** |
| `chem-balance` | `qwen3:14b` | 11% | 0% | **-11** |
| `chem-balance` | `qwen3-coder:30b-a3b-q4_K_M` | 29% | 0% | **-29** |
| `dijkstra` | `qwen3:14b` | 100% | 0% | **-100** |

_Across 12 (eval × model) pairs with both single-pass and multi-step: 2 improved with a pipeline. Mean delta = **-9.7 pts**._

