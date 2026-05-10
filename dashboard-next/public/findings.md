# 🍋 Findings

_292 runs · 29 evals · 8 harnesses · 10 models. Auto-generated._

## Harness scoreboard

| harness | avg | cells |
|---|---:|---:|
| `squeezer-critique` | **88.4** | 14 |
| `aider` | **74.1** | 161 |
| `squeezer-architect` | **60.2** | 12 |
| `squeezer-tdd` | **57.7** | 12 |
| `qa` | **57.3** | 12 |
| `squeezer-verify` | **52.2** | 12 |
| `pi` | **45.1** | 31 |
| `squeezer` | **21.7** | 3 |

## Model scoreboard

| model | avg | cells |
|---|---:|---:|
| `qwen3:8b` | **88.7** | 3 |
| `gpt-oss:20b` | **85.1** | 46 |
| `llama3.1:8b` | **78.1** | 7 |
| `qwen3-coder:30b-a3b-q4_K_M` | **77.9** | 55 |
| `qwen2.5:14b` | **70.2** | 25 |
| `mistral-small:24b` | **70.0** | 27 |
| `qwen3:14b` | **60.6** | 62 |
| `devstral:24b` | **48.3** | 16 |
| `phi4:14b` | **11.6** | 8 |
| `granite3.3:8b` | **10.0** | 8 |

## Alchemy: multi-step vs single-pass

| eval | model | single-pass | multi-step | Δ |
|---|---|---:|---:|---:|
| `sql-injection-fix` | `qwen3:14b` | 65% | 85% | **+20** |
| `sql-injection-fix` | `gpt-oss:20b` | 85% | 100% | **+15** |
| `bug-fix` | `qwen3:14b` | 100% | 100% | **+0** |
| `fft-spectrum` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `dijkstra` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `base64-codec` | `gpt-oss:20b` | 75% | 75% | **+0** |
| `crc-checksum` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `dijkstra` | `qwen3:14b` | 100% | 100% | **+0** |
| `cli-tool` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `sql-injection-fix` | `qwen3-coder:30b-a3b-q4_K_M` | 85% | 85% | **+0** |
| `cli-tool` | `qwen3:14b` | 100% | 100% | **+0** |
| `engineering` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `bug-fix` | `qwen3-coder:30b-a3b-q4_K_M` | 100% | 100% | **+0** |
| `chem-balance` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `kepler-orbit` | `qwen3-coder:30b-a3b-q4_K_M` | 100% | 100% | **+0** |

_Across 22 (eval × model) pairs with both single-pass and multi-step: 2 improved with a pipeline. Mean delta = **-5.3 pts**._

