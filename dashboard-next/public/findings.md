# 🍋 Findings

_5665 runs · 74 evals · 22 harnesses · 59 models. Auto-generated._

## Harness scoreboard

| harness | avg | cells |
|---|---:|---:|
| `codex-cloud` | **99.4** | 49 |
| `cloud-ensemble` | **98.0** | 100 |
| `pi-cloud` | **97.8** | 11 |
| `claude-code-cloud` | **97.6** | 49 |
| `opencode-cloud` | **97.6** | 49 |
| `cline-cloud` | **95.4** | 49 |
| `cloud-verify` | **95.3** | 150 |
| `crush-cloud` | **94.9** | 49 |
| `aider-cloud` | **93.7** | 105 |
| `squeezer-cloud` | **88.6** | 1533 |
| `cloud-architect` | **82.9** | 200 |
| `cloud-critique` | **79.5** | 200 |
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
| `codex` | **99.4** | 49 |
| `kimi-k2.7-code` | **98.2** | 60 |
| `deepseek-v4-flash` | **98.1** | 66 |
| `ens:3cheap<-pro` | **98.1** | 50 |
| `gpt-5.5` | **98.1** | 60 |
| `ens:3mid<-glm5.1` | **97.8** | 50 |
| `claude-code` | **97.6** | 49 |
| `arch:flash<-pro` | **97.5** | 50 |
| `crit:120b<-glm5.1` | **97.4** | 50 |
| `deepseek-v3.2` | **97.4** | 50 |
| `claude-opus-4.8` | **97.3** | 65 |
| `glm-4.7` | **97.1** | 50 |
| `arch:120b<-qwenmax` | **97.0** | 50 |
| `deepseek-v4-pro` | **97.0** | 271 |
| `qwen3-max` | **96.8** | 60 |
| `arch:30b<-pro` | **96.7** | 50 |
| `glm-5.1` | **96.3** | 60 |
| `verify:120b` | **96.2** | 50 |
| `glm-4.6` | **95.8** | 49 |
| `verify:pro` | **95.8** | 50 |
| `nemotron-3-120b` | **95.6** | 50 |
| `minimax-m3` | **95.5** | 50 |
| `minimax-m2.7` | **95.1** | 50 |
| `verify:30b` | **93.8** | 50 |
| `gpt-oss-120b` | **93.8** | 72 |
| `crit:30b<-pro-r2` | **93.2** | 50 |
| `crit:30b<-pro` | **92.9** | 50 |
| `qwen3-235b-2507` | **92.6** | 50 |
| `devstral-2512` | **92.1** | 50 |
| `qwen3-coder-480b` | **91.1** | 50 |
| `qwen3-coder-plus` | **90.8** | 50 |
| `glm-5.2` | **89.6** | 10 |
| `qwen3-coder-30b` | **89.5** | 77 |
| `kimi-k2-thinking` | **88.5** | 50 |
| `gpt-oss-20b` | **84.3** | 50 |
| `codestral-2508` | **83.9** | 50 |
| `qwen3-14b` | **81.8** | 50 |
| `qwen3-32b` | **81.6** | 50 |
| `mistral-small-3.2` | **80.8** | 75 |
| `gpt-oss:20b` | **75.1** | 95 |
| `deepseek-r1` | **74.9** | 50 |
| `qwen3-coder:30b-a3b-q4_K_M` | **73.5** | 54 |
| `qwen3-coder:30b` | **71.9** | 16 |
| `llama3.1:8b` | **70.0** | 11 |
| `qwen3:8b` | **69.1** | 7 |
| `qwen2.5:14b` | **63.2** | 29 |
| `command-r7b` | **62.0** | 1 |
| `llama-3.3-70b` | **61.8** | 50 |
| `mistral-small:24b` | **58.6** | 30 |
| `qwen3:14b` | **56.7** | 62 |
| `qwen2.5-coder:14b` | **52.6** | 19 |
| `gemma4:e4b` | **50.7** | 7 |
| `llama-3.1-8b` | **41.6** | 71 |
| `arch:llama8b<-pro` | **40.4** | 50 |
| `devstral:24b` | **38.6** | 20 |
| `crit:llama8b<-pro` | **34.4** | 50 |
| `phi4:14b` | **25.0** | 11 |
| `mistral-nemo:12b` | **23.0** | 1 |
| `granite3.3:8b` | **19.1** | 11 |

## Alchemy: multi-step vs single-pass

| eval | model | single-pass | multi-step | Δ |
|---|---|---:|---:|---:|
| `sql-injection-fix` | `qwen3:14b` | 65% | 85% | **+20** |
| `sql-injection-fix` | `gpt-oss:20b` | 85% | 100% | **+15** |
| `password-strength` | `gpt-oss:20b` | 93% | 100% | **+7** |
| `dijkstra` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `sql-injection-fix` | `qwen3-coder:30b-a3b-q4_K_M` | 85% | 85% | **+0** |
| `dijkstra` | `qwen3:14b` | 100% | 100% | **+0** |
| `kepler-orbit` | `qwen3-coder:30b-a3b-q4_K_M` | 100% | 100% | **+0** |
| `projectile-sim` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `engineering` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `fft-spectrum` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `port-scanner` | `gpt-oss:20b` | 20% | 20% | **+0** |
| `regression-ci` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `cli-tool` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `great-circle` | `gpt-oss:20b` | 100% | 100% | **+0** |
| `crc-checksum` | `gpt-oss:20b` | 100% | 100% | **+0** |

_Across 40 (eval × model) pairs with both single-pass and multi-step: 3 improved with a pipeline. Mean delta = **-14.2 pts**._

