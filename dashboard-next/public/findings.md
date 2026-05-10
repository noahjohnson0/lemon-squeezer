# 🍋 Findings

_193 runs · 26 evals · 6 harnesses · 9 models. Auto-generated._

## Harness scoreboard

Average best-score across all (eval × model) cells the harness has played:

| harness | avg | cells | best | weakest |
|---|---:|---:|---|---|
| `aider` | **69.1** | 118 | 100% on `bug-fix`/`qwen3:14b` | 0% on `crc-checksum`/`granite3.3:8b` |
| `squeezer-critique` | **66.1** | 7 | 100% on `bug-fix`/`qwen3:14b` | 0% on `refactor`/`qwen3:14b` |
| `squeezer-tdd` | **57.7** | 12 | 100% on `bug-fix`/`qwen3:14b` | 0% on `chem-balance`/`qwen3-coder:30b-a3b-q4_K_M` |
| `squeezer-verify` | **45.1** | 7 | 100% on `bug-fix`/`qwen3:14b` | 0% on `dijkstra`/`qwen3:14b` |
| `pi` | **44.9** | 31 | 100% on `bug-fix`/`qwen3-coder:30b-a3b-q4_K_M` | 0% on `port-scanner`/`devstral:24b` |
| `squeezer` | **32.5** | 2 | 65% on `sql-injection-fix`/`qwen3:14b` | 0% on `chem-balance`/`qwen3:14b` |

## Harness gap (single eval × model, multiple harnesses)

Top 12 (eval, model) combos where harness choice mattered most:

| eval | model | gap | top | bottom |
|---|---|---:|---|---|
| `cli-tool` | `gpt-oss:20b` | **+100** | `aider` 100% | `pi` 0% |
| `refactor` | `qwen3:14b` | **+100** | `aider` 100% | `squeezer-critique` 0% |
| `port-scanner` | `gpt-oss:20b` | **+100** | `aider` 100% | `pi` 0% |
| `password-strength` | `devstral:24b` | **+100** | `aider` 100% | `pi` 0% |
| `dijkstra` | `qwen3:14b` | **+100** | `aider` 100% | `squeezer-verify` 0% |
| `cli-tool` | `devstral:24b` | **+90** | `aider` 90% | `pi` 0% |
| `password-strength` | `qwen3:14b` | **+86** | `aider` 86% | `pi` 0% |
| `wifi-stats` | `gpt-oss:20b` | **+85** | `aider` 94% | `pi` 9% |
| `port-scanner` | `devstral:24b` | **+85** | `aider` 85% | `pi` 0% |
| `bug-fix` | `qwen3:14b` | **+73** | `aider` 100% | `pi` 27% |
| `bug-fix` | `devstral:24b` | **+73** | `aider` 100% | `pi` 27% |
| `password-strength` | `gpt-oss:20b` | **+64** | `aider` 93% | `pi` 29% |

## Model scoreboard

Average best-score across all (eval × harness) cells per model:

| model | avg | cells | dominant harness |
|---|---:|---:|---|
| `qwen3:8b` | **88.7** | 3 | `aider` (89) |
| `qwen3-coder:30b-a3b-q4_K_M` | **78.5** | 40 | `squeezer-verify` (100) |
| `gpt-oss:20b` | **78.4** | 34 | `squeezer-critique` (100) |
| `qwen2.5:14b` | **65.1** | 8 | `aider` (65) |
| `llama3.1:8b` | **64.2** | 8 | `aider` (64) |
| `qwen3:14b` | **58.5** | 52 | `aider` (75) |
| `devstral:24b` | **47.6** | 16 | `aider` (71) |
| `phi4:14b` | **11.6** | 8 | `aider` (12) |
| `granite3.3:8b` | **10.0** | 8 | `aider` (10) |

## Alchemy: do multi-step pipelines beat single-pass?

| eval | model | single-pass best | multi-step best | Δ |
|---|---|---:|---:|---:|
| `sql-injection-fix` | `qwen3:14b` | 65% | 85% | **+20** |
| `sql-injection-fix` | `gpt-oss:20b` | 85% | 100% | **+15** |
| `bug-fix` | `qwen3-coder:30b-a3b-q4_K_M` | 100% | 100% | **+0** |
| `sql-injection-fix` | `qwen3-coder:30b-a3b-q4_K_M` | 85% | 85% | **+0** |
| `bug-fix` | `qwen3:14b` | 100% | 100% | **+0** |
| `cli-tool` | `qwen3:14b` | 100% | 100% | **+0** |
| `chem-balance` | `qwen3-coder:30b-a3b-q4_K_M` | 0% | 0% | **+0** |
| `chem-balance` | `qwen3:14b` | 0% | 0% | **+0** |
| `dijkstra` | `qwen3-coder:30b-a3b-q4_K_M` | 100% | 100% | **+0** |
| `wifi-stats` | `qwen3:14b` | 81% | 78% | **-3** |
| `wifi-stats` | `qwen3-coder:30b-a3b-q4_K_M` | 91% | 83% | **-8** |
| `dijkstra` | `qwen3:14b` | 100% | 0% | **-100** |
| `refactor` | `qwen3:14b` | 100% | 0% | **-100** |

_Across 13 (eval × model) pairs that have both single-pass and multi-step runs: 2 pairs improved with a pipeline, 4 got worse, 7 tied. Mean delta = **-13.5 points**._

## Cost / efficiency

Total energy used per model (Wh extrapolated from sampled GPU avg power × wall-clock). Only counts runs with telemetry.

| model | runs | telemetered | total Wh | per-run avg Wh |
|---|---:|---:|---:|---:|
| `qwen3:14b` | 59 | 36 | 354.43 | 9.845 |
| `qwen3-coder:30b-a3b-q4_K_M` | 45 | 24 | 33.62 | 1.401 |
| `phi4:14b` | 8 | 8 | 23.04 | 2.880 |
| `gpt-oss:20b` | 36 | 21 | 18.18 | 0.866 |
| `granite3.3:8b` | 8 | 8 | 9.42 | 1.177 |
| `qwen2.5:14b` | 8 | 8 | 5.54 | 0.692 |
| `llama3.1:8b` | 8 | 8 | 2.32 | 0.290 |
| `qwen3:8b` | 3 | 3 | 2.14 | 0.714 |
| `devstral:24b` | 18 | 4 | 1.74 | 0.435 |

