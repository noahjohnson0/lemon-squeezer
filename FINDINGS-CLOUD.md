# The Fable Destroyer — open weights on OpenRouter

After Fable 5's export-control suspension (2026-06-12), this is the cloud half of
lemon-squeezer: the same `squeezer` agent and the same rubrics as the local 4070
benchmark, pointed at open-weight models (and multi-model mixes) on OpenRouter.

**The sweep:** 18 arms (11 single models + 7 mixes) × 16 evals × ~2.6 trials =
**751 runs, $9.89, 0 errors.** Driven by `bin/cloud-matrix`, scored by each
eval's real `rubric.sh`. Reproduce: `bin/cloud-matrix --tag fable-hunt`.

## Leaderboard

`$/$` = mean score per cent spent per task (bang-for-buck; higher is better).

| arm | type | mean % | $/task | score/$ | latency |
|---|---|---:|---:|---:|---:|
| **deepseek-v4-flash** | single | **100.0** | $0.0018 | 565 | 66s |
| kimi-k2.7-code | single | 99.7 | $0.0118 | 84 | 50s |
| arch:120b←qwen-max | **mix** | 99.5 | $0.0034 | 297 | 61s |
| deepseek-v4-pro | single | 99.5 | $0.0177 | 56 | 112s |
| verify:pro | mix | 99.2 | $0.0408 | 24 | 163s |
| glm-5.1 | single | 98.3 | $0.0103 | 95 | 48s |
| qwen3-max | single | 98.0 | $0.0067 | 146 | 21s |
| crit:120b←glm5.1 | mix | 97.9 | $0.0358 | 27 | 231s |
| ens:3cheap←pro | mix | 97.6 | $0.0288 | 34 | 297s |
| **gpt-oss-120b** | single | 95.0 | **$0.0005** | **1923** | 37s |
| glm-4.7 | single | 94.9 | $0.0067 | 142 | 44s |
| crit:30b←pro | mix | 94.3 | $0.0441 | 21 | 318s |
| verify:30b | mix | 91.8 | $0.0098 | 94 | 93s |
| qwen3-coder-480b | single | 89.1 | $0.0053 | 168 | 59s |
| minimax-m2.7 | single | 87.5 | $0.0060 | 147 | 59s |
| gpt-oss-20b | single | 76.9 | $0.0009 | 864 | 16s |
| arch:30b←pro | mix | 76.3 | $0.0077 | 100 | 76s |
| qwen3-coder-30b | single | 69.4 | $0.0013 | 520 | 21s |

## Verdict

**1. The Fable destroyer is a single cheap model.** `deepseek-v4-flash` is the
only arm that scored 100% on all 16 evals, at **~$0.0018/task** — ~250× cheaper
than a frontier-closed model would cost. The whole frontier-open tier
(deepseek-v4-pro, kimi-k2.7-code, glm-5.1, qwen3-max) sits at 98–100%. On *this*
suite, the open-weight gap to a banned frontier model is essentially closed.

**2. Best value: `gpt-oss-120b`** — 95% at **$0.0005/task** (1923 score/$), ~4×
cheaper than anything close to it on quality. If you're paying per token at
scale, this is the default.

**3. Mixes mostly do NOT beat the best single — they *rescue weak ones*.** No mix
beat `deepseek-v4-flash`, and the heavy mixes (critique, ensemble, verify with a
frontier reviewer) cost 5–25× more and run 3–5× slower for *lower* scores. But
look at what they do to a weak executor (`qwen3-coder-30b`, 69.4% alone):

| treatment of qwen3-coder-30b | mean % | $/task | latency |
|---|---:|---:|---:|
| alone | 69.4 | $0.0013 | 21s |
| + self-verify (write tests, iterate) | 91.8 | $0.0098 | 93s |
| + frontier critic (draft→critique→refine) | 94.3 | $0.0441 | 318s |
| architect plan (deepseek-v4-pro) → it implements | 76.3 | $0.0077 | 76s |

Critique and self-verification turn a 69% model into a ~92–94% one. Architecting
helps less here (a good plan can't save sloppy implementation). The one clean mix
win is **architect-on-a-decent-executor**: `gpt-oss-120b` 95.0 → 99.5 when
`qwen3-max` writes the plan first (`arch:120b←qwen-max`), and it's cheap ($0.0034).

**So:** if a strong cheap single exists (it does — deepseek-v4-flash, gpt-oss-120b),
just use it. Reach for a mix when you're stuck with a weak/tiny model, when you
want test-backed robustness (verify), or to squeeze a near-perfect score out of a
cheap model with a one-shot architect plan.

## Where the field actually separated

Most evals are "everyone gets 100%." The signal lives in a handful of hard ones:

- **regex-engine** — split the field hard (ensemble 67, qwen3-max 74, crit:30b 79).
- **matrix-ops** — gpt-oss-20b 17, glm-5.1 76, minimax 76; even frontier arms dipped to 93.
- **fft-spectrum / rate-limiter** — qwen3-coder-30b scored **0**; deepseek-v4-flash 100.
- **knapsack** — qwen3-coder-30b 33, arch:30b←pro 33.
- **kalman-filter** — gpt-oss-120b 75 (its only real miss).

The cheap small models (gpt-oss-20b, qwen3-coder-30b) don't fail *everywhere* —
they fail *specifically* on the algorithmically dense tasks. That's the gap a
mix (or a bigger model) is buying back.

## Local vs cloud

The 4070, with the right harness, is closer than you'd think. Best broad-coverage
local arm on this suite (12 of 16 evals it has run):

| where | best arm | mean % | cost |
|---|---|---:|---|
| **local (RTX 4070)** | `gpt-oss:20b` + aider | 97.0 | electricity |
| **cloud (open)** | `deepseek-v4-flash` | 100.0 | $0.0018/task |
| **cloud (value)** | `gpt-oss-120b` | 95.0 | $0.0005/task |

A free GPU you own gets ~97%. A fraction of a cent per task in the cloud gets you
the last few points, robustness on the hardest evals, and access to 480B+ models
that won't fit in 12 GB. Neither requires asking a frontier lab for permission.

*Generated from `runs.jsonl` (tag `fable-hunt`). Live: the
[/cloud dashboard](https://noahjohnson0.github.io/lemon-squeezer/cloud).*
