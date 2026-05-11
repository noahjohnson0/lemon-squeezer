# 🍋 Findings

_355 runs · 30 evals · 9 harnesses · 12 models. Auto-generated._

## Harness scoreboard

| harness | avg | cells |
|---|---:|---:|
| `squeezer-critique` | **85.5** | 31 |
| `aider` | **64.7** | 187 |
| `squeezer-architect` | **60.2** | 12 |
| `squeezer-tdd` | **57.7** | 12 |
| `qa` | **57.6** | 27 |
| `squeezer-verify` | **52.2** | 12 |
| `pi` | **45.1** | 31 |
| `squeezer` | **21.7** | 3 |
| `librarian` | **17.6** | 5 |

## Model scoreboard

| model | avg | cells |
|---|---:|---:|
| `gpt-oss:20b` | **83.2** | 64 |
| `qwen3-coder:30b-a3b-q4_K_M` | **77.9** | 55 |
| `qwen2.5:14b` | **70.4** | 28 |
| `mistral-small:24b` | **68.5** | 28 |
| `command-r7b` | **62.0** | 1 |
| `qwen3:14b` | **59.7** | 63 |
| `llama3.1:8b` | **53.8** | 13 |
| `devstral:24b` | **48.3** | 16 |
| `phi4:14b` | **24.5** | 11 |
| `qwen3:8b` | **21.7** | 29 |
| `granite3.3:8b` | **18.6** | 11 |
| `command-r:35b` | **0.0** | 1 |

## Alchemy: multi-step vs single-pass

| eval | model | single-pass | multi-step | Δ |
|---|---|---:|---:|---:|
| `sql-injection-fix` | `qwen3:14b` | 65% | 85% | **+20** |
| `sql-injection-fix` | `gpt-oss:20b` | 85% | 100% | **+15** |
| `password-strength` | `gpt-oss:20b` | 93% | 100% | **+7** |
| `crc-checksum` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `bug-fix` | `qwen3-coder:30b-a3b-q4_K_M` | 100% | 100% | **+0** |
| `base64-codec` | `gpt-oss:20b` | 75% | 75% | **+0** |
| `kalman-filter` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `dijkstra` | `qwen3:14b` | 100% | 100% | **+0** |
| `great-circle` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `kepler-orbit` | `qwen3-coder:30b-a3b-q4_K_M` | 100% | 100% | **+0** |
| `dijkstra` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `cli-tool` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `dijkstra` | `qwen3-coder:30b-a3b-q4_K_M` | 100% | 100% | **+0** |
| `projectile-sim` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `sql-injection-fix` | `qwen3-coder:30b-a3b-q4_K_M` | 85% | 85% | **+0** |

_Across 39 (eval × model) pairs with both single-pass and multi-step: 3 improved with a pipeline. Mean delta = **-9.7 pts**._

