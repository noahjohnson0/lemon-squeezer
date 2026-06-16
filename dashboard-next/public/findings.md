# 🍋 Findings

_4949 runs · 74 evals · 16 harnesses · 56 models. Auto-generated._

## Harness scoreboard

| harness | avg | cells |
|---|---:|---:|
| `cloud-ensemble` | **97.8** | 80 |
| `cloud-verify` | **95.8** | 120 |
| `aider-cloud` | **89.8** | 56 |
| `squeezer-cloud` | **88.1** | 1303 |
| `cloud-architect` | **82.2** | 160 |
| `cloud-critique` | **79.7** | 160 |
| `squeezer-critique` | **77.5** | 32 |
| `aider` | **70.0** | 172 |
| `squeezer-local` | **62.8** | 47 |
| `squeezer-architect` | **60.2** | 12 |
| `squeezer-tdd` | **57.7** | 12 |
| `qa` | **52.6** | 33 |
| `squeezer-verify` | **52.2** | 12 |
| `pi` | **40.4** | 30 |
| `squeezer` | **39.6** | 5 |
| `librarian` | **34.1** | 19 |

## Model scoreboard

| model | avg | cells |
|---|---:|---:|
| `deepseek-v4-pro` | **98.1** | 54 |
| `gpt-5.5` | **98.1** | 60 |
| `ens:3cheap<-pro` | **98.0** | 40 |
| `kimi-k2.7-code` | **98.0** | 50 |
| `deepseek-v4-flash` | **98.0** | 56 |
| `ens:3mid<-glm5.1` | **97.6** | 40 |
| `crit:120b<-glm5.1` | **97.4** | 40 |
| `deepseek-v3.2` | **97.4** | 40 |
| `verify:pro` | **97.4** | 40 |
| `arch:flash<-pro` | **97.3** | 40 |
| `claude-opus-4.8` | **97.3** | 65 |
| `arch:30b<-pro` | **97.3** | 40 |
| `glm-4.7` | **97.1** | 40 |
| `arch:120b<-qwenmax` | **97.0** | 40 |
| `gpt-oss-120b` | **96.9** | 62 |
| `qwen3-max` | **96.5** | 50 |
| `verify:120b` | **96.4** | 40 |
| `glm-5.1` | **96.3** | 50 |
| `crit:30b<-pro` | **96.2** | 40 |
| `nemotron-3-120b` | **95.0** | 40 |
| `glm-4.6` | **95.0** | 39 |
| `minimax-m3` | **94.9** | 40 |
| `minimax-m2.7` | **94.0** | 40 |
| `crit:30b<-pro-r2` | **93.8** | 40 |
| `verify:30b` | **93.6** | 40 |
| `qwen3-coder-480b` | **93.4** | 40 |
| `qwen3-235b-2507` | **92.3** | 40 |
| `devstral-2512` | **90.4** | 40 |
| `qwen3-coder-plus` | **89.3** | 40 |
| `qwen3-coder-30b` | **88.0** | 77 |
| `kimi-k2-thinking` | **87.7** | 40 |
| `gpt-oss-20b` | **83.0** | 50 |
| `qwen3-14b` | **80.5** | 50 |
| `codestral-2508` | **80.2** | 40 |
| `mistral-small-3.2` | **80.0** | 75 |
| `qwen3-32b` | **79.5** | 40 |
| `deepseek-r1` | **75.5** | 40 |
| `gpt-oss:20b` | **75.1** | 95 |
| `qwen3-coder:30b-a3b-q4_K_M` | **73.5** | 54 |
| `qwen3-coder:30b` | **71.9** | 16 |
| `llama3.1:8b` | **70.0** | 11 |
| `qwen3:8b` | **69.1** | 7 |
| `qwen2.5:14b` | **63.2** | 29 |
| `command-r7b` | **62.0** | 1 |
| `llama-3.3-70b` | **59.6** | 40 |
| `mistral-small:24b` | **58.6** | 30 |
| `qwen3:14b` | **56.7** | 62 |
| `qwen2.5-coder:14b` | **52.6** | 19 |
| `gemma4:e4b` | **50.7** | 7 |
| `llama-3.1-8b` | **42.3** | 61 |
| `devstral:24b` | **38.6** | 20 |
| `arch:llama8b<-pro` | **37.4** | 40 |
| `crit:llama8b<-pro` | **31.3** | 40 |
| `phi4:14b` | **25.0** | 11 |
| `mistral-nemo:12b` | **23.0** | 1 |
| `granite3.3:8b` | **19.1** | 11 |

## Alchemy: multi-step vs single-pass

| eval | model | single-pass | multi-step | Δ |
|---|---|---:|---:|---:|
| `sql-injection-fix` | `qwen3:14b` | 65% | 85% | **+20** |
| `sql-injection-fix` | `gpt-oss:20b` | 85% | 100% | **+15** |
| `password-strength` | `gpt-oss:20b` | 93% | 100% | **+7** |
| `port-scanner` | `gpt-oss:20b` | 20% | 20% | **+0** |
| `lru-cache` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `engineering` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `cli-tool` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `kepler-orbit` | `qwen3-coder:30b-a3b-q4_K_M` | 100% | 100% | **+0** |
| `bug-fix` | `qwen3:14b` | 100% | 100% | **+0** |
| `dijkstra` | `qwen3:14b` | 100% | 100% | **+0** |
| `hamming-code` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `cli-tool` | `qwen3:14b` | 100% | 100% | **+0** |
| `chem-balance` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `kalman-filter` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `bug-fix` | `qwen3-coder:30b-a3b-q4_K_M` | 100% | 100% | **+0** |

_Across 40 (eval × model) pairs with both single-pass and multi-step: 3 improved with a pipeline. Mean delta = **-14.2 pts**._

