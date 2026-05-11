# 🍋 Findings

_366 runs · 30 evals · 9 harnesses · 16 models. Auto-generated._

## Harness scoreboard

| harness | avg | cells |
|---|---:|---:|
| `squeezer-critique` | **85.5** | 31 |
| `aider` | **64.7** | 187 |
| `squeezer-architect` | **60.2** | 12 |
| `squeezer-tdd` | **57.7** | 12 |
| `qa` | **52.6** | 33 |
| `squeezer-verify` | **52.2** | 12 |
| `pi` | **45.1** | 31 |
| `librarian` | **30.8** | 9 |
| `squeezer` | **21.7** | 3 |

## Model scoreboard

| model | avg | cells |
|---|---:|---:|
| `gpt-oss:20b` | **84.8** | 64 |
| `qwen3-coder:30b-a3b-q4_K_M` | **77.9** | 55 |
| `qwen2.5:14b` | **70.4** | 28 |
| `mistral-small:24b` | **68.5** | 28 |
| `command-r7b` | **62.0** | 1 |
| `qwen3:14b` | **60.5** | 63 |
| `llama3.1:8b` | **53.8** | 13 |
| `qwen2.5-coder:14b` | **44.7** | 3 |
| `devstral:24b` | **41.9** | 20 |
| `phi4:14b` | **24.5** | 11 |
| `mistral-nemo:12b` | **23.0** | 1 |
| `qwen3:8b` | **21.7** | 29 |
| `granite3.3:8b` | **18.6** | 11 |
| `command-r:35b` | **0.0** | 1 |
| `deepseek-coder-v2:16b` | **0.0** | 1 |
| `gemma3:12b` | **0.0** | 1 |

## Alchemy: multi-step vs single-pass

| eval | model | single-pass | multi-step | Δ |
|---|---|---:|---:|---:|
| `sql-injection-fix` | `qwen3:14b` | 65% | 85% | **+20** |
| `sql-injection-fix` | `gpt-oss:20b` | 85% | 100% | **+15** |
| `password-strength` | `gpt-oss:20b` | 93% | 100% | **+7** |
| `levenshtein` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `chem-balance` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `sql-injection-fix` | `qwen3-coder:30b-a3b-q4_K_M` | 85% | 85% | **+0** |
| `kalman-filter` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `bug-fix` | `qwen3-coder:30b-a3b-q4_K_M` | 100% | 100% | **+0** |
| `engineering` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `fft-spectrum` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `bug-fix` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `base64-codec` | `gpt-oss:20b` | 75% | 75% | **+0** |
| `cli-tool` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `hamming-code` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `kepler-orbit` | `gpt-oss:20b` | 100% | 100% | **+0** |

_Across 39 (eval × model) pairs with both single-pass and multi-step: 3 improved with a pipeline. Mean delta = **-9.7 pts**._

