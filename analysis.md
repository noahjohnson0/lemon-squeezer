# Local-LLM coding-agent benchmark: comparative analysis

Dataset: 44 scored runs across 4 evals (`bug-fix`, `cli-tool`, `refactor`, `wifi-stats`), 2 harnesses (`aider`, `pi`), 4 main models (`qwen3:14b`, `qwen3-coder:30b-a3b-q4_K_M`, `gpt-oss:20b`, `devstral:24b`), and 6 config tags (`baseline`, `skills`, `sysprompt`, `sysprompt2`, `directive`, `whole-fmt`). Three `chem-balance` runs are present but unscored (`?`); the `projectile-sim` and one `comprehensive` run did not produce a `meta.json`/`score.json` and are excluded.

## Section 1: The harness gap (pi vs aider)

Pairing each `(eval, model)` and taking each harness'''s *best* tag, the aider-pi delta is overwhelming.

| eval         | model                          | best aider | best pi | delta (aider-pi) |
|--------------|--------------------------------|------------|---------|------------------|
| bug-fix      | devstral:24b                   | 100        | 27      | +73              |
| bug-fix      | gpt-oss:20b                    | 100        | 100     |  0               |
| bug-fix      | qwen3-coder:30b-a3b            | 100        | 100     |  0               |
| bug-fix      | qwen3:14b                      | 100        | 27      | +73              |
| cli-tool     | devstral:24b                   |  90        |  0      | +90              |
| cli-tool     | gpt-oss:20b                    | 100        |  0      | +100             |
| cli-tool     | qwen3-coder:30b-a3b            | 100        | 54      | +46              |
| cli-tool     | qwen3:14b                      | 100        | 54      | +46              |
| refactor     | devstral:24b                   |  53        | 53      |  0               |
| refactor     | gpt-oss:20b                    | 100        | 100     |  0               |
| refactor     | qwen3-coder:30b-a3b            |  66        | 66      |  0               |
| refactor     | qwen3:14b                      | 100        | 53      | +47              |
| wifi-stats   | devstral:24b                   |  83        | 48      | +35              |
| wifi-stats   | gpt-oss:20b                    |  94        |  9      | +85              |
| wifi-stats   | qwen3-coder:30b-a3b            |  91        | 79      | +12              |
| wifi-stats   | qwen3:14b                      |  81        | 66      | +15              |

Median delta = **+40.5**; mean delta = **+38.9**; worst gap = **+100** (`gpt-oss:20b` cli-tool); aider never lost on best-of-tag. Aider'''s single greatest advantage is its `whole` edit format: the model returns the full file body inside fenced blocks and aider replaces the file. There is no string-level diff that has to "match".

Pi exposes the local models to a structured-tool API where edits must specify an `oldText` that exactly matches existing bytes. Local models are bad at this. Run `2026-05-10T04-44-45Z_bug-fix_pi_qwen3_14b_sysprompt` (qwen3:14b, bug-fix, pi, score 9%) is the canonical example. The first edit attempt invented `oldText` from imagination:

```
"oldText": "for row in reader:\n        total += int(row[1])"
```

...but the actual code was `s += int(row[1])`. Tool returned: *"Could not find edits[0] in csv_total.py. The oldText must match exactly including all whitespace and newlines."* The model then read the file (good), retried, and the patch *applied* - but with a structural bug: the `try:` was opened inside the loop while `except:` landed at the loop level, producing this:

```python
def total(path):
    s = 0
    with open(path) as f:
        reader = csv.reader(f)
        next(reader)  # skip header
        for row in reader:
            try:
            s += int(row[1])      # IndentationError
        except ValueError:
            pass
    return s
```

The file does not even compile. That'''s the difference between 100% on aider and 9% on pi for the same model on the same task. A second mode of pi failure is "no tool call at all": qwen3:14b on `2026-05-10T06-23-52Z_refactor_pi_qwen3_14b_baseline` produced 4429 output tokens of prose and *zero* edits - the workspace `orders.py` was unchanged from the broken original; it scored 53% only because the original happens to compile and produce the right output. devstral:24b on `2026-05-10T06-09-44Z_cli-tool_pi_devstral_24b_baseline` produced an empty assistant message (87 tokens, zero tool calls) and the workspace stayed empty -> 0/30. gpt-oss:20b on `2026-05-10T06-08-57Z_cli-tool_pi_gpt_oss_20b_baseline` printed a fully-formed Python program inside a markdown fence, never called the `write` tool, scored 0/30.

**Takeaway:** if you are running local models in the 14B-30B range, the harness is the dominant variable. A whole-file rewrite harness (aider'''s `whole` format) recovers ~40 score points on average vs a structured-tool harness like pi. The pi-style harness only pays off on models trained heavily on JSON tool-use; among the four tested, only qwen3-coder:30b is consistently competent at it (it matched aider on bug-fix and refactor, lost only 12 pts on wifi-stats).

## Section 2: Model-by-model character

Per-model summary across all evals, separated by harness:

| model                     | harness | n | avg score | median wall (s) | median tok_in | median tok_out |
|---------------------------|---------|---|-----------|-----------------|---------------|----------------|
| qwen3:14b                 | aider   | 6 | 86.6      | 76              |   786         | 1900           |
| qwen3:14b                 | pi      | 8 | 43.5      | 62              |  5482         | 2735           |
| qwen3-coder:30b-a3b       | aider   | 6 | 87.5      | 68              |   784         | 1290           |
| qwen3-coder:30b-a3b       | pi      | 4 | 74.8      | 112             | 21036         | 1840           |
| gpt-oss:20b               | aider   | 6 | 89.3      | 89              |   843         | 1866           |
| gpt-oss:20b               | pi      | 4 | 52.2      | 48              |  4446         |  918           |
| devstral:24b              | aider   | 6 | 79.0      | 136             |  1200         |  863           |
| devstral:24b              | pi      | 4 | 32.0      | 72              |  4104         |  574           |

### qwen3-coder:30b-a3b-q4_K_M
Best generalist for tool-use harnesses. **Strength:** wifi-stats with `directive` config in aider - 91% on `2026-05-10T06-47-21Z_wifi-stats_aider_qwen3_coder_30b_a3b_q4_K_M_directive`, the highest score on the hardest eval after gpt-oss/sysprompt. Also the only model that scored 100% on `bug-fix` *under pi* (`2026-05-10T06-06-45Z`). Its MoE 3B-active design makes it fast: median 68s on aider, fastest of the four. **Weakness:** refactor - 66% on both harnesses. On `2026-05-10T06-25-37Z_refactor_aider_qwen3_coder_30b_a3b_q4_K_M_baseline` it correctly factored out `customer_total(order)` but rewrote the input data structure entirely, mutating tuples like `("apple", 3, 1.50)` into dicts `{"name": "apple", "price": 1.5, "quantity": 2}` with **different quantities**, producing `alice paid 8.0` instead of the required `alice paid 8.5`. It "improved" the dataset and broke the spec.

### gpt-oss:20b
Highest aider-only average (89.3), but the highest harness sensitivity in the dataset: 94% on aider/wifi-stats/sysprompt vs 9% on pi/wifi-stats/sysprompt - an 85-point collapse with the same prompt and config. **Strength:** wifi-stats with `sysprompt` on aider - 94% (`2026-05-10T05-59-02Z`); also 100% on every aider baseline for bug-fix/cli-tool/refactor. **Weakness:** any task on pi that requires writing files. On `2026-05-10T06-08-57Z_cli-tool_pi_gpt_oss_20b_baseline` it produced 565 tokens of perfectly-shaped Python in a chat reply and never called `write` - pi exited with an empty workspace (0/30). gpt-oss seems to have been trained for chat-style code generation, not for the OpenAI-style function-call schema pi presents. **Counter-intuitively** it is the *cheapest* model on pi by token-count (median 4446 in / 918 out) precisely because it just says "here is the code:" and stops.

### qwen3:14b
The cheapest competent model on aider (smallest, fastest, lowest tok_in). **Strength:** every aider baseline - 100% on bug-fix, cli-tool, refactor; 81% on wifi-stats with sysprompt. **Weakness:** its pi-harness behaviour is the worst-documented in the dataset. It is the model behind the botched-edit example in Section 1: 9% on `bug-fix_pi_..._sysprompt` because the `try`/`except` indentation got mangled mid-edit. Counter-intuitively, *adding* the sysprompt on pi made bug-fix worse (27 -> 9), apparently because the longer system prompt pushed the model into more verbose/multi-step plans that ran into more `oldText`-mismatch errors. On the wifi-stats sequence it scored 48 -> 33 -> 58 -> 66 across baseline/skills/sysprompt/sysprompt2 - i.e. the "skills" tag actively hurt it (5837 input tokens consumed for 33% score), while the leaner `sysprompt2` topped it.

### devstral:24b
The biggest disappointment on pi (avg 32%). **Strength:** wifi-stats on aider (`sysprompt` 83%, `whole-fmt` 78%, baseline 70%) - it doesn'''t dominate any single check but is consistent. **Weakness:** it has a lethal habit on pi of replying "Let me check the content first:" and then **stopping without calling the read tool**. Run `2026-05-10T06-09-19Z_bug-fix_pi_devstral_24b_baseline` is exactly this: 87 output tokens of "I'''ll help you fix..." and then `stopReason=stop` with no tool calls. The pi cli-tool run from one minute later scored 0/30 the same way (empty workspace). Its 53/53 on the refactor eval on both harnesses is also the *floor* score: that'''s just what you get if you leave the file untouched and the original happens to print correct output. devstral consumes 1200 tok_in / 863 tok_out median on aider and yet scores well there; it'''s not a capability ceiling, it'''s a tool-use floor.

ASCII profile (avg score across all evals, by harness):

```
qwen3-coder  aider |#################### 87.5
qwen3-coder  pi    |################# 74.8
gpt-oss:20b  aider |##################### 89.3
gpt-oss:20b  pi    |############ 52.2
qwen3:14b    aider |##################### 86.6
qwen3:14b    pi    |########## 43.5
devstral:24b aider |################# 79.0
devstral:24b pi    |####### 32.0
```

## Section 3: Sysprompt effect

The wifi-stats eval is the only one with enough config variation to compare. Below, scores for `wifi-stats` with each model+harness+tag:

| model            | harness | baseline | skills | sysprompt | sysprompt2 | directive | whole-fmt |
|------------------|---------|----------|--------|-----------|------------|-----------|-----------|
| qwen3:14b        | aider   |    52    |   -    |    81     |     -      |    -      |    -      |
| qwen3:14b        | pi      |    48    |   33   |    58     |    66      |    -      |    -      |
| qwen3-coder:30b  | aider   |    83    |   -    |    85     |     -      |    91     |    -      |
| qwen3-coder:30b  | pi      |    -     |   -    |    79     |     -      |    -      |    -      |
| gpt-oss:20b      | aider   |    56    |   -    |    94     |     -      |    86     |    -      |
| gpt-oss:20b      | pi      |    -     |   -    |     9     |     -      |    -      |    -      |
| devstral:24b     | aider   |    70    |   -    |    83     |     -      |    -      |    78     |
| devstral:24b     | pi      |    -     |   -    |    48     |     -      |    -      |    -      |

Key effects:
- **`sysprompt` (general-hygiene.md) helps almost everywhere** on aider: +29 for qwen3:14b, +13 for devstral, +2 for qwen3-coder, **+38 for gpt-oss**. The biggest single boost in the dataset.
- **`directive` is more-targeted but inconsistent.** It pulled qwen3-coder up from 85 -> 91 (the dataset high tied with gpt-oss/sysprompt at 94), but pulled gpt-oss *down* from 94 -> 86 - an 8-point regression on the same eval. `directive.md` instructs the model to "list each requirement and one specific implementation choice" before coding; gpt-oss is verbose enough that this seems to push it past the point of diminishing returns (6200 tokens out on `sysprompt`, 3600 on `directive` - fewer tokens, more truncation, fewer files). The lesson: "more rigorous" prompts are not monotonically better; gpt-oss already self-checks. **Less is more for the talkative model.**
- **`skills` actively hurt qwen3:14b on pi** (48 -> 33). It loaded extra context (5837 tok_in vs 2876 baseline) without giving the model any new useful procedure. Bigger context, fewer/sloppier tool calls.
- **`sysprompt2` (same content as `sysprompt`, different injection point) edged out `sysprompt` on pi for qwen3:14b** (66 vs 58 on wifi-stats). Pi'''s `--append-system-prompt` injection seems to land cleaner than aider'''s `--read` style for that model.
- **`whole-fmt` (aider with `--edit-format whole`) actually hurt devstral slightly** vs sysprompt with default format (78 vs 83). devstral'''s strength on aider is *because* of the whole format; forcing it doesn'''t help further.

## Section 4: Per-eval insights

**bug-fix.** Trivially small task: fix one ~8-line script (skip header, swallow `ValueError`, sum to 100). 9 runs, avg 73.7%, range 9-100. The check that separates models is `outputs:100` (33% fail rate); `compiles` only fails 11% of the time. Surprise: the failures cluster on pi with weak tool-use (qwen3:14b 27%/9%, devstral 27%); on aider every model gets 100%. This is the eval that proves harness > model.

**cli-tool.** Build a `wc` clone with `--help` and a non-zero exit on missing file. 8 runs, avg 62.2% - the lowest avg of the four. The two pi runs that scored 0% (devstral, gpt-oss) didn'''t write the file at all. Where the file does exist, the dominant failure is `output:exact_format` (50% - models add commas, tabs, extra spaces or print more than four fields), followed by `help:has_usage` (38% - the `--help` text doesn'''t include the literal word `usage` or the script name). Surprise: even on aider, devstral lost 10 pts (`2026-05-10T05-44-09Z`) for misformatted help - the only sub-100 aider cli-tool run.

**refactor.** Extract a `customer_total(order)` function. 8 runs, avg 73.9%. The semantic checks dominate the failures: `defines:customer_total` and `uses:customer_total` each fail 50% - they look for the function defined AND called in a comprehension/loop. `output:identical` fails 12% (one run). Surprise: qwen3-coder:30b scored 66% on *both* harnesses because it correctly refactored but rewrote the input data, breaking output identity (`run 2026-05-10T06-25-37Z`). devstral hit 53/53 on both harnesses, which is the floor - the rubric awards file/compiles/output points to a literally-untouched original.

**wifi-stats.** Greenfield Next.js + FastAPI app, 15 weighted checks. 18 runs, avg 66.7%, range 9-94. Hardest checks across all runs: `backend:cors_configured` (67% fail), `frontend:use_client_directive` (56%), `frontend:absolute_or_proxied_fetch` (56%), `readme:node_install` (56%), `backend:uses_modern_wifi_cmd` (44%, Sonoma deprecated `airport -I`). These are exactly the four bullets that the `general-hygiene.md` sysprompt warns about - and indeed the sysprompt configs add ~15-40 score points whenever the model has the capacity to act on them. Surprise: scaffold checks (`file:backend/*.py`, `frontend:layout_tsx`, `frontend:package_json`) fail 6-39% - small models genuinely forget root files in App Router projects.

**chem-balance / projectile-sim.** Three chem-balance runs and one projectile-sim run exist in the workspace but are unscored (`score_pct: "?"`) - qwen3:14b'''s chem-balance attempt produced a `balance.py` that crashed every test case with `AttributeError("'''str''' object has no attribute '''get'''")` (run `2026-05-10T07-03-39Z`, score from `score.json` would be 11/85 = ~13%). These tasks expose a different failure mode (genuine algorithmic inability with linear-algebra null-space solving) and aren'''t directly comparable to the four core evals.

## Section 5: Recommendation

For someone running coding agents on a single 4070-class GPU (<=16 GB usable VRAM after overhead, so 14B Q4 / 20B-MoE / 24B Q4 territory):

**Greenfield (multi-file, framework boilerplate):**
- Model: `gpt-oss:20b` - best on aider/wifi-stats with `sysprompt` (94%).
- Harness: `aider` with default `whole` edit format. Do not use pi.
- Config: `--read configs/general-hygiene.md` (the `sysprompt` tag). Do **not** layer `directive.md` on top - it cost gpt-oss 8 points.
- Fallback: `qwen3-coder:30b-a3b-q4_K_M` is a hair behind (91% with `directive`) and ~2x faster (median 68s vs 89s). If you have the VRAM headroom, prefer it for iterative dev work.

**Editing existing code (bug-fix, refactor, in-place modifications):**
- Model: `qwen3:14b` or `qwen3-coder:30b-a3b` - both 100% on bug-fix and refactor with aider baseline.
- Harness: `aider`. The `whole` edit format means the model never has to reproduce a string verbatim from a 1000-line file; it just emits the full new version. Pi-style structured edits multiply the failure surface - half of pi'''s failures in this dataset were `oldText`-mismatch loops or just no-tool-call replies.
- Config: baseline is fine for small files; sysprompt only matters for tasks that touch CLIs/network/CORS.
- **Avoid** `devstral:24b` for any pi/structured-tool harness. Its training does not include reliable tool-call emission; it will reply in prose and stop. On aider it is competent but not best.

**General rules:**
- Treat the harness as a first-class hyperparameter. The median (eval, model) gap between best aider and best pi is **+40 pts**. If you must use a structured-tool harness for sandbox-isolation reasons, *only* run `qwen3-coder:30b-a3b` on it (74.8 avg on pi, vs <=52 for the others).
- Keep system prompts minimal. The "skills" run on qwen3:14b/pi (-15 pts vs baseline) and "directive" on gpt-oss/aider (-8 pts vs sysprompt) are explicit warnings: extra context can drown a small model. Add hygiene only.
- Watch for "produced code, never wrote a file": if the workspace is empty after a run, it is almost always a model-tool-protocol mismatch, not a model-capability problem. Switching to aider'''s whole format will rescue most of these runs at no extra cost.
