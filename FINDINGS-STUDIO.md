# Findings: big local models as tool-calling agents (Mac Studio)

Which open-weight model that fits in 128 GB of unified memory is the best local agent for real
tool-calling work? This is the third venue of lemon-squeezer: a **Mac Studio M5 Max, 128 GB**
(GPU wired limit raised to 120 GB), serving one model at a time with llama.cpp.

> **Status: exploration, final pass pending.** Everything below was run while the harness was still
> changing: one trial per task, and harness bugs were found and fixed between runs (listed below), so
> rows from different days are not on identical code. A **final pass** (frozen harness, all 64 tasks,
> fresh workspaces at a seed offset never used in exploration, one pass per model) is running now and
> is the result. Treat the exploration numbers as a screen, not a ranking. The tables refresh with
> `bin/studio-refresh` (see *Reproduce*).

This track is a different benchmark from the coding suite in [FINDINGS-CLOUD.md](FINDINGS-CLOUD.md):
not "write a program and pass a rubric" but "use the tools you are given to change the state of a
small world": files on disk, a mailbox, a message database, an intranet. Scores are not comparable
across the two tracks.

## Setup

- **Agent harness.** A jailed tool-calling agent (the worker runs in Docker) whose tasks are scored on
  the **end state** (files on disk, mailbox labels, sent drafts), never on what the model says it did.
  Each task has several checks; a task is *solved* only when every check passes.
- **Toolsets.** `lean+`: 18 file/search/app tools (read/write/edit, bulk move and rename recipes,
  semantic search over the workspace, Gmail and browser look-alikes, verify and rollback), no code
  execution. `lean+x`: lean+ plus `run_python` (120 s per call, own container, workspace only, no
  network). `pi`: the pi coding agent's four tools (bash/read/write/edit).
- **Tasks.** The 37 screening tasks: basic 8, stress 5, hard 9, general 5, apps 10 (Gmail, iMessage
  and intranet look-alikes, with prompt-injection traps). **HARD2**, 15 tasks written when the 37
  saturated: dirty data, buried policy exceptions, multi-app joins, stale caches, partial-failure
  recovery, injected instructions. **HARD3**, 12 tasks written when HARD2 saturated: data behind
  per-item mail and browser calls (cannot be scripted in one call), 60-110-call ledgers, conflicting
  specs with a stated precedence, resume without duplicate side effects, requests that must be
  refused, and two code tasks where the checker runs the agent's own regression test. Every HARD2 and
  HARD3 task has a reference solution that passes and a check that an untouched workspace fails.
- **Serving.** llama.cpp `llama-server --jinja`, 131k context, full offload. Reasoning is sent back
  between tool calls for models that think (dropping it is known to break gpt-oss: 6/13 vs 11/13 on an
  earlier M4 Max run). Sampling per model card. Max 150 steps, 16k-token reply cap.
- **Models** (the largest quant that leaves room for 131k context):

| model | quant | GB | notes |
|---|---|---:|---|
| Edge0-145B | NVFP4 | ~60 resident | latent-MoE rebuild of Qwen3.8-Flash-Next (145B total, 6.6B active); served by its own engine, not llama.cpp; a 51 GB embedding table is read from SSD |
| Qwen3.8-Flash-Next | UD-Q3_K_XL | 89 | |
| Ornith-1.5-122B | UD-Q4_K_XL | 80 | |
| Nemotron-3.5-Super-120B | UD-Q4_K_XL | 87 | |
| Nemotron-3.5-Bolt-74B | UD-Q6_K_XL | 72 | |
| Laguna-S-2.1 | UD-Q4_K_XL | 73 | |
| Qwen3.5-122B-A10B | UD-Q4_K_XL | 77 | |
| Qwen3-Coder-Next | UD-Q6_K_XL | 73 | |
| gpt-oss-120b (base, and llmfan46 ultra-heretic) | MXFP4 | 63 / 65 | reasoning effort medium (default) and high |
| Mistral-Small-4-119B | UD-Q4_K_XL | 74 | |
| Qwen3-235B-A22B (original and abliterated) | i1-IQ3_M | 103 | 65k context with q8 KV: at 131k it ran out of memory |
| Ripple-65B-Preview | Q8_0 | 69 | dense 65B, mostly sliding-window attention |

The question and design were preregistered before the first episode, and every change after that was
written down as a dated amendment with what had been seen at the time. That log is the source of the
"what changed and why" sections below.

## What the exploration shows (single trials, moving harness)

- **The 37 screening tasks saturate.** Edge0-145B and Qwen3.8-Flash-Next both solved **37/37**; five
  more models sit at 33-34. Between the top two the outcomes are identical, task for task.
- **The harder suites saturate too, at the very top.** On HARD2 both Qwen3.8-Flash-Next and Edge0
  solved **15/15** (Nemotron-3.5-Super 13/15): the top models read the spec, dump the data with one
  `run_python` call and script the rest. On HARD3 Edge0 solved **11/12** and Qwen3.8-Flash-Next
  **9/12**, but that comparison is not clean: Qwen3.8's three misses are exactly the three checks that
  were found broken and fixed before Edge0 ran (see bug 11 below), and Edge0's one miss was a fourth
  checker bug (a numbered `1. REFUSED:` item not read as a REFUSED line), which would make it 12/12.
  Whether Qwen3.8 passes those tasks under the fixed checkers is for the final pass to say.
- **Edge0 is the fastest at the top**: ~89 decode tok/s on its own engine against ~52 for
  Qwen3.8-Flash-Next on llama.cpp; 37 tasks in 39 min vs 49 min. Its weights are a rebuild of
  Qwen3.8-Flash-Next, so this is as much an engine comparison as a model one.
- **Code execution is the biggest single lever.** On the four models run both ways, adding
  `run_python` moved them from 100 to 117 solved over 35 shared tasks (+17, 95% CI +3 to +33,
  resampling tasks). Without it, models write a script they cannot run and then try to do the
  computation in their reasoning until they hit the reply cap (one worked out a CRC-32 by hand).
  Per model the gain is +3 to +5 tasks, each too wide to call on its own; an earlier M4 Max run of
  Qwen3.6-35B-A3B showed the same, 15/27 without exec vs 22/27 with it.
- **Abliteration did not change tool use.** gpt-oss-120b base and its ultra-heretic version solved the
  same number of tasks on both toolsets (22 = 22 without exec, 29 = 29 with). They differed in one
  place: the heretic obeyed a prompt injection planted in an order-status page; the base did not.
- **MLX vs llama.cpp on gpt-oss-120b (reasoning high): llama.cpp 31/37, MLX 29/37,** too wide to call.
  Throughput was equal (67 vs 66 completion tok/s over wall time). MLX lost 7 replies to tool calls its
  harmony parser still could not read (invalid JSON, prose written into a header); llama.cpp's grammar
  makes those impossible. llama.cpp stays the engine.
- **Reasoning effort**: gpt-oss-120b at high effort solved 31/37 vs 29/37 at medium (too wide to call)
  and took four times as long (63 vs 16 min).
- **Middle tier**: Qwen3.5-122B, Nemotron-3.5-Bolt and Laguna-S-2.1 at 33, Qwen3-Coder-Next and
  gpt-oss-120b (high) at 31. Qwen3.8-Flash-Next is ahead of its predecessor Qwen3.5-122B (+4 tasks,
  CI +1 to +8), the one single-model gap in the screen whose CI clears zero.
- **Failure modes are model-side once the harness bugs are out**: false "done" claims with the work
  undone, one swapped pair of letters when writing an answer, missed receipts that say neither
  "receipt" nor "order confirmation", and reasoning loops that run to the reply cap (Laguna's four
  misses are all `out_of_tokens`).

## The harness bugs (a lesson for any agent benchmark)

Much of the exploration's value was finding these. Each made a model look worse (or, for the
isolation bug, could have made one look better) than it was, and each was fixed with a test before
the final pass. Rows run before a fix are not rerun: they are exploration, kept as found.

1. **llama.cpp's tool-call grammar forces schema key order.** The bulk-move recipe schema listed
   `glob` after `src`/`dst`; the grammar only accepts keys in schema order, so gpt-oss could never add
   a glob once it had written `dst` (0 of 733 gpt-oss calls had keys out of order) and looped.
   Fixed by moving `glob` up and then making it required, so the grammar always emits it.
2. **The Gmail mock silently ignored `( )` groups and `from:(a OR b)`**, returned zero hits, and
   gpt-oss concluded the mailbox was empty. Now a real query parser (OR binds tighter than AND,
   groups, negation, `op:(...)`). Brace globs (`*.{a,b}`) also matched nothing.
3. **A reply cut off at the token cap in the middle of a tool call was executed** and sent back as
   broken JSON; the next request died with HTTP 500 and the trial with it. It now ends the trial as
   `out_of_tokens`.
4. **A tool exception of an unexpected type escaped and crashed the worker** (editing a binary
   database, a non-string count). The task then reran from scratch in a new run dir: a silent second
   try that turned two failures into passes. Every tool exception now goes back to the model as a
   tool error.
5. **Checkers crashed on `__pycache__`** that models left behind when they imported their own code to
   test it: good behaviour scored as a fail. Checkers skip bytecode; `run_python` sets
   `PYTHONDONTWRITEBYTECODE`.
6. **The system prompt said "file-management agent".** gpt-oss then declined a refund-triage task with
   "the tools available to me are limited to managing files". It now names the apps. The same pass
   added "nobody will answer questions: assume, say what you assumed, finish", after gpt-oss at high
   effort answered a task with questions for the user.
7. **Reasoning was off by default for Mistral-Small-4.** Its chat template defaults to
   `reasoning_effort: none` and the model config never set it: 1 of 993 turns reasoned, 20 of 25
   failures claimed done with the work undone. That 12/37 row is reported as "reasoning off", not as
   the model; with reasoning on it went 3/5 on the smoke check.
8. **The 235B ran out of memory at 131k context** (103 GB of weights). It ran at 65k with q8 KV, so its
   rows are not on the same context as the others.
9. **`run_python` could read the harness.** It ran inside the worker container, which had the whole
   harness mounted read-only: checkers, expected answers, HARD2 reference solutions. No model did (702
   `run_python` calls scanned, none touched a path outside the workspace), but it now runs in a fresh
   container per call with only the task's workspace mounted, no network and a read-only root, with a
   test that the harness paths do not exist inside it.
10. **The world clock vs the host clock.** The simulated world (mailbox, intranet, task data) is fixed
    at 2026-10-28; the host clock was three weeks later. In the first final-pass attempt Ornith asked
    Python for today's date, computed "30 days ago" from the real date and archived the wrong
    newsletters. The system prompt now states the world's date and `run_python` runs under `faketime`
    at it. That attempt's rows were set aside and the final pass restarted.
11. **HARD3 checker bugs**, found by the exploration rows before the final pass: the two code checkers
    copied only part of the workspace, so an agent's regression test that read a data file failed on a
    correct fix; the refund task's prompt named a policy file (`REFUNDS.md`) that was never created;
    and a numbered `1. REFUSED:` line was not read as a REFUSED line.
12. **Queue bookkeeping**: rows killed when the server was stopped mid-task were counted as done; they
    are now retried.

The general lessons: score the end state, not the transcript; read every failure before believing it
(roughly half of the first day's failures were the harness); check what a grammar-constrained decoder
can and cannot emit; jail code execution away from the answers; pin the clock; and give every checker
a reference solution that passes *and* an untouched workspace that fails.

## Serving gpt-oss on MLX: harmony tool-call parser fixes

`mlx_lm.server` could not serve gpt-oss as a tool-calling agent at first (the harmony-format calls
came back as text; 14 of 14 episodes gave up). The open mlx-lm PR #2049 adds a harmony parser, but it
still dropped calls in 3 of 5 tasks. Three shapes in the raw text were not handled, and a small patch
on top of the PR fixes them (with tests):

1. **Code-typed calls with a raw body**: `run_python code<|message|>import json ...`. The payload is
   code, not JSON. The patch maps it to the tool's single string parameter when the header says
   `code`.
2. **Stray header text before the channel**:
   `verify to=assistant<|channel|>commentary json<|message|>{...}`. The patch accepts any header text
   between the function name and `<|message|>`.
3. **A channel with no name**: `click<|channel|><|constrain|>json<|message|>{...}`.

It also logs the raw text of a call that still fails to parse. What remains after the patch is
model-side (invalid JSON, prose written into a header), which is exactly what llama.cpp's grammar
prevents; hence the 31 vs 29 above.

## What was dropped, and why

- **lean+ (no exec)** after one pass of five models: a setup known to fail (see above). Kept as the
  paired no-exec baseline. Nemotron-3.5-Super's lean+ pass was stopped partway (22 of 37 tasks).
- **Qwen3.5-122B** from the final: Qwen3.8-Flash-Next supersedes it (37 vs 33).
- **Both Qwen3-235B variants**: 3/5 (abliterated) and 1/5 (original) on the smoke check, and the
  slowest models (up to 16 min a task). The original scoring *below* the abliterated one says the
  trouble is an older model squeezed to 3 bits, not abliteration.
- **The middle tier** (Qwen3-Coder-Next, gpt-oss-120b base/high/heretic, Mistral-Small-4) from the
  final pass: it cannot change the winner, and the final pass is time-boxed to the week.
- **MLX**: an engine A/B, not a model; llama.cpp won it on reliability at equal speed.
- **A 3-seed final pass** was planned and cut to one pass per model to finish within the week. With
  one seed, a gap of one to three tasks between the top two is expected to be too wide to call.
- **The pi harness** was run on the best model only (Qwen3.8-Flash-Next: 29/30 on the tasks pi can
  attempt, vs 30/30 with lean+x on the same tasks).

## Exploration tables

<!-- studio:exploration:begin -->
_Generated by `bin/studio-summary` from `studio/rows/`. tok/s is llama.cpp's decode rate where the row has timings, else (marked *) completion tokens over wall time, which includes prefill and tool time._

#### lean+x, the 37 screening tasks

| model | quant | solved | 95% CI (Wilson) | checks | fails by stop reason | wall | tok/s |
|---|---|---:|---:|---:|---|---:|---:|
| Edge0-145B | NVFP4 (own engine) | **37/37** | 91-100% | 170/170 | - | 39 min | 89.1 |
| Qwen3.8-Flash-Next | UD-Q3_K_XL | **37/37** | 91-100% | 170/170 | - | 49 min | 45.9* |
| Nemotron-3.5-Super-120B | UD-Q4_K_XL | **34/37** | 79-97% | 166/170 | done 3 | 72 min | 32.7* |
| Ornith-1.5-122B | UD-Q4_K_XL | **34/37** | 79-97% | 163/166 | done 2, out_of_tokens 1 | 85 min | 43.1* |
| Qwen3.5-122B-A10B | UD-Q4_K_XL | **33/37** | 75-96% | 164/170 | done 4 | 66 min | 41.4* |
| Nemotron-3.5-Bolt-74B | UD-Q6_K_XL | **33/37** | 75-96% | 162/166 | done 4 | 71 min | 36.4* |
| Laguna-S-2.1 | UD-Q4_K_XL | **33/37** | 75-96% | 161/170 | out_of_tokens 4 | 99 min | 47.0* |
| Qwen3-Coder-Next | UD-Q6_K_XL | **31/37** | 69-92% | 159/170 | done 6 | 28 min | 51.3* |
| gpt-oss-120b (reasoning high) | MXFP4 | **31/37** | 69-92% | 158/170 | done 5, repeat_loop 1 | 63 min | 67.0* |
| gpt-oss-120b heretic (abliterated) | MXFP4 | **29/37** | 63-89% | 154/170 | done 8 | 20 min | 65.7* |
| gpt-oss-120b (reasoning high, MLX) | MXFP4-Q8 | **29/37** | 63-89% | 154/170 | done 5, empty_reply 3 | 46 min | 66.0* |
| gpt-oss-120b | MXFP4 | **29/37** | 63-89% | 153/170 | done 7, repeat_loop 1 | 16 min | 76.4* |
| Mistral-Small-4-119B (reasoning off by mistake) | UD-Q4_K_XL | **12/37** | 20-48% | 122/170 | done 20, empty_reply 1, max_steps 2, repeat_loop 2 | 64 min | 31.7* |

#### lean+x, HARD2 (15 harder tasks)

| model | quant | solved | 95% CI (Wilson) | checks | fails by stop reason | wall | tok/s |
|---|---|---:|---:|---:|---|---:|---:|
| Edge0-145B | NVFP4 (own engine) | **15/15** | 80-100% | 108/108 | - | 32 min | 91.9 |
| Qwen3.8-Flash-Next | UD-Q3_K_XL | **15/15** | 80-100% | 108/108 | - | 51 min | 52.1 |
| Nemotron-3.5-Super-120B | UD-Q4_K_XL | **13/15** | 62-96% | 103/108 | done 1, out_of_tokens 1 | 113 min | 35.0 |

#### lean+x, HARD3 (12 long-horizon tasks)

| model | quant | solved | 95% CI (Wilson) | checks | fails by stop reason | wall | tok/s |
|---|---|---:|---:|---:|---|---:|---:|
| Edge0-145B | NVFP4 (own engine) | **11/12** | 65-98% | 124/125 | done 1 | 42 min | 94.1 |
| Qwen3.8-Flash-Next | UD-Q3_K_XL | **9/12** | 47-91% | 114/125 | done 3 | 74 min | 51.6 |

#### lean+ (no code execution), 37 tasks

| model | quant | solved | 95% CI (Wilson) | checks | fails by stop reason | wall | tok/s |
|---|---|---:|---:|---:|---|---:|---:|
| Ornith-1.5-122B | UD-Q4_K_XL | **29/37** | 63-89% | 153/170 | done 2, out_of_tokens 5, request_error 1 | 165 min | 40.9* |
| Qwen3.5-122B-A10B | UD-Q4_K_XL | **27/37** | 57-85% | 150/170 | done 5, out_of_tokens 5 | 156 min | 37.5* |
| Nemotron-3.5-Super-120B (partial) | UD-Q4_K_XL | **14/22** | 43-80% | 85/108 | done 1, out_of_tokens 3, request_error 4 | 67 min | 33.1* |
| gpt-oss-120b | MXFP4 | **22/37** | 44-74% | 145/170 | done 13, out_of_tokens 1, repeat_loop 1 | 79 min | 24.2* |
| gpt-oss-120b heretic (abliterated) | MXFP4 | **22/37** | 44-74% | 140/170 | done 10, out_of_tokens 2, repeat_loop 2, request_error 1 | 39 min | 65.6* |

#### pi harness (bash/read/write/edit), 30 tasks

| model | quant | solved | 95% CI (Wilson) | checks | fails by stop reason | wall | tok/s |
|---|---|---:|---:|---:|---|---:|---:|
| Qwen3.8-Flash-Next | UD-Q3_K_XL | **29/30** | 83-99% | 136/138 | done 1 | 41 min | 50.5 |

#### 5-task smoke checks

| model | quant | solved | 95% CI (Wilson) | checks | fails by stop reason | wall | tok/s |
|---|---|---:|---:|---:|---|---:|---:|
| Ripple-65B-Preview (dense) | Q8_0 | **5/5** | 57-100% | 28/28 | - | 88 min | 7.5 |
| Qwen3-235B-A22B abliterated | i1-IQ3_M, 65k ctx | **3/5** | 23-88% | 24/28 | done 1, empty_reply 1 | 14 min | 26.5 |
| Mistral-Small-4-119B (reasoning high) | UD-Q4_K_XL | **3/5** | 23-88% | 22/28 | done 2 | 6 min | 47.6 |
| Qwen3-235B-A22B | i1-IQ3_M, 65k ctx | **1/5** | 4-62% | 18/28 | done 2, empty_reply 2 | 27 min | 23.8 |

#### Paired comparisons (bootstrap over tasks, 95% CI on the difference in tasks solved)

| A vs B | tasks | A | B | A-B [95% CI] | verdict |
|---|---:|---:|---:|---:|---|
| Edge0-145B vs Qwen3.8-Flash-Next, 37 tasks | 37 | 37 | 37 | +0 [+0, +0] | same tasks solved |
| Edge0-145B vs Qwen3.8-Flash-Next, HARD2 | 15 | 15 | 15 | +0 [+0, +0] | same tasks solved |
| Edge0-145B vs Qwen3.8-Flash-Next, HARD3 | 12 | 11 | 9 | +2 [-2, +6] | too wide to call (HARD3 checkers were fixed between these two runs (FINDINGS-STUDIO.md, bug 11)) |
| Qwen3.8-Flash-Next vs Nemotron-3.5-Super, HARD2 | 15 | 15 | 13 | +2 [+0, +5] | too wide to call |
| Qwen3.8-Flash-Next vs Nemotron-3.5-Super, 37 tasks | 37 | 37 | 34 | +3 [+0, +7] | too wide to call |
| Qwen3.8-Flash-Next vs Qwen3.5-122B, 37 tasks | 37 | 37 | 33 | +4 [+1, +8] | A ahead |
| gpt-oss-120b: llama.cpp vs MLX (both reasoning high) | 37 | 31 | 29 | +2 [-3, +7] | too wide to call |
| gpt-oss-120b: reasoning high vs medium | 37 | 31 | 29 | +2 [-2, +6] | too wide to call |
| gpt-oss-120b: base vs heretic (abliteration), lean+x | 37 | 29 | 29 | +0 [-5, +5] | too wide to call |
| gpt-oss-120b: base vs heretic (abliteration), lean+ | 37 | 22 | 22 | +0 [-4, +4] | too wide to call |
| Qwen3.8-Flash-Next: lean+x vs pi harness, 30 tasks | 30 | 30 | 29 | +1 [+0, +3] | too wide to call (pi has no mail or browser tools, so only the 30 tasks without them) |
| gpt-oss-120b: lean+x vs lean+ (code execution) | 35 | 27 | 22 | +5 [+0, +10] | too wide to call (35 tasks: release_zip and vendor_unpack need exec, so they are left out) |
| gpt-oss-120b heretic (abliterated): lean+x vs lean+ (code execution) | 35 | 27 | 22 | +5 [-1, +11] | too wide to call (35 tasks: release_zip and vendor_unpack need exec, so they are left out) |
| Qwen3.5-122B-A10B: lean+x vs lean+ (code execution) | 35 | 31 | 27 | +4 [+0, +9] | too wide to call (35 tasks: release_zip and vendor_unpack need exec, so they are left out) |
| Ornith-1.5-122B: lean+x vs lean+ (code execution) | 35 | 32 | 29 | +3 [-3, +9] | too wide to call (35 tasks: release_zip and vendor_unpack need exec, so they are left out) |
| lean+x vs lean+ (code execution), 4 models pooled | 35 | 117 | 100 | +17 [+3, +33] | A ahead (35 tasks x 4 models, bootstrap resamples tasks) |
<!-- studio:exploration:end -->

## Final pass

Top 6 by exploration (Edge0-145B, Qwen3.8-Flash-Next, Nemotron-3.5-Super-120B, Ornith-1.5-122B,
Nemotron-3.5-Bolt-74B, Laguna-S-2.1) plus Ripple-65B (run last: ~7 tok/s), all 64 tasks (37 + HARD2 +
HARD3), lean+x, frozen harness (hashed before the start), seed offset 10000, one pass each.
Pairwise differences: bootstrap over tasks, "too wide to call" when the 95% CI includes zero.

<!-- studio:final:begin -->
**State: running.** One pass per model, 64 tasks, frozen harness, seed offset 10000. Partial rows show progress only; a model's score counts once its pass is done.

| model | progress | solved | 37 / HARD2 / HARD3 | 95% CI (Wilson) | checks | fails by stop reason | wall | tok/s |
|---|---:|---:|---:|---:|---:|---|---:|---:|
| Ornith-1.5-122B (partial) | 37/64 | ... | ... | ... | ... | ... | ... | ... |
<!-- studio:final:end -->

## Honesty / limits

- **One trial per task, everywhere.** A Wilson interval on 37 tasks is roughly +-10 points; most
  pairwise gaps in the screen are inside the noise. Only the pooled code-execution effect and
  Qwen3.8-Flash-Next over Qwen3.5-122B have CIs that clear zero.
- **Moving harness.** Exploration rows were run before, between and after the fixes above. Rows from
  before a fix understate the models it hit (gpt-oss most of all).
- **Not a matched quantization.** Each model ran at the largest quant that fits with 131k context
  (Q3 to Q8), which is the practical question on this box but not a like-for-like model comparison.
  Edge0 also runs on a different engine.
- **Home-field tasks.** The tasks, tools and checkers are ours, and the harness is not public yet;
  the task names, check names and every per-task row are, in [`studio/rows/`](studio/rows/).
- **The world clock bug** (number 10) could hit any date-relative task in the exploration rows too;
  the final pass is the first run with the world date pinned.

## Reproduce

```bash
bin/studio-summary          # rebuild studio/summary.json, the /studio page data and the tables above
bin/studio-refresh          # pull the newest rows from the Studio first (needs STUDIO_SSH, STUDIO_DIR)
bin/studio-refresh --pr     # same, in a throwaway worktree off origin/main, opened as a PR
```

`studio/rows/<tag>.jsonl` holds one row per task: model, task, suite, checks passed/total, solved,
steps, tool calls and errors, tokens, timings where llama.cpp reported them, wall time, stop reason
and the names of the failed checks. Tags are `<model>[.<toolset>][.<suite>][.s<seed>]`; no toolset
means lean+, no suite means the 37 screening tasks. `studio/tags.json` says which passes finished.
Live: the [/studio dashboard](https://noahjohnson0.github.io/lemon-squeezer/studio/).
