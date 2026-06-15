**Prioritized Findings**

1. **CRITICAL - Agents can read and tamper with the entire benchmark.**  
   Location: `bin/squeezer.py:58`, `bin/squeezer.py:61`, `bin/squeezer.py:62`, `bin/cloud-run:248`  
   `read_file` is path-checked, but `run_bash` runs arbitrary shell in the workspace with no filesystem sandbox. A model can `cat ../../../../evals/<eval>/rubric.sh`, read every hidden check, overwrite rubrics, inspect `runs.jsonl`, and inherit API env vars. This contaminates **every eval**.  
   Fix: run the agent in a locked container/jail with only the workspace mounted, no repo parent, no secrets, no network unless explicitly part of the eval; run scoring from an immutable host-side rubric after the agent process exits.

2. **CRITICAL - 25 rubrics can award 100% to an import-broken stub.**  
   Location: `evals/dijkstra/rubric.sh:50`, `evals/regex-engine/rubric.sh:66`, `evals/matrix-ops/rubric.sh:67`, `evals/base64-codec/rubric.sh:61`, `evals/rate-limiter/rubric.sh:70`  
   Many rubrics skip `IMPORT_ERR` lines and never add zeroes for behavior checks. A valid Python file with no required function can get file + compile + static bonus, then the denominator collapses to only those checks. A non-solution can score 100. Affected: base64-codec, bloom-filter, boolean-sat, crc-checksum, dc-circuit, dijkstra, engineering, fft-spectrum, finance, great-circle, hamming-code, huffman, json-schema, julian-day, kalman-filter, kepler-orbit, knapsack, levenshtein, lru-cache, matrix-ops, rate-limiter, regex-engine, regression-ci, solar-position, state-machine-engine.  
   Fix: predeclare the full check list and weights; on import failure, add all behavioral checks as failed. Never let the denominator depend on emitted stdout.

3. **CRITICAL - The published harness bake-off is not controlled.**  
   Location: `bin/cloud-matrix:51`, `bin/cloud-matrix:66`, `bin/cloud-matrix:164`, `README.md:37`, `FINDINGS-CLOUD.md:12`  
   Resume keys ignore `tag`, so the `bakeoff` run skipped many squeezer cells because old `fable-hunt` rows already existed. Current `bakeoff` data has aider 154 rows vs squeezer 55 rows. The published table mixes fable-hunt squeezer means with bakeoff aider means while claiming “same model, same evals, only harness changes.”  
   Fix: include `tag`, suite version, trial id, seed, harness version, and config hash in resume keys. Discard the current bake-off and rerun paired cells only.

4. **HIGH - Parallel runs can collide into the same run directory.**  
   Location: `bin/cloud-run:55`, `bin/cloud-run:154`, `bin/cloud-matrix:160`, `bin/cloud-matrix:214`  
   `run_id` uses second-resolution timestamps and no trial UUID. With `--trials > 1` and small suites, multiple identical eval/arm/tag cells can launch in the same second and write the same workspace/meta files.  
   Fix: add trial index plus random UUID to `run_id`; use atomic exclusive directory creation and fail on collision.

5. **HIGH - Reporting drops failures from means and reports misleading n.**  
   Location: `bin/cloud-report:52`, `bin/cloud-report:55`, `bin/cloud-report:58`, `bin/cloud-report:70`  
   Rows with `score_pct: "?"` increment `n`, cost, and eval coverage but are excluded from `scores`, inflating means while printing an `n` that is not the number of scored observations.  
   Fix: treat parse/score failures as 0 unless explicitly excluded with a separate failed-run table. Report `n_total`, `n_scored`, and `n_failed`.

6. **HIGH - The CI math is not statistically defensible.**  
   Location: `bin/cloud-report:60`, `bin/cloud-report:62`, `bin/cloud-report:66`, `bin/cloud-report:81`  
   The CI assumes IID runs, ignores eval clustering and paired design, uses z instead of t, and invents `half = 50` for `n < 2`. Two identical lucky runs get `[100-100]`. Sorting by this lower bound is not “n-aware shrinkage.”  
   Fix: aggregate per eval first, then compare paired eval means; use bootstrap over evals or a hierarchical model. For low n, report “insufficient data,” not a fake interval.

7. **HIGH - Dashboard rankings use best-of trials, creating winner’s curse.**  
   Location: `dashboard-next/src/lib/data.ts:133`, `dashboard-next/src/lib/data.ts:139`, `dashboard-next/src/components/Leaderboard.tsx:30`, `dashboard-next/src/lib/data.ts:146`  
   `bestPer` keeps the maximum score for each eval/model/harness cell, then averages maxima. The “Bayesian” shrink is just `(n*avg + 3*globalMean)/(n+3)` with arbitrary `C=3` and a biased global mean.  
   Fix: compute per-cell means over all valid trials, include failures, and rank by uncertainty-aware paired estimates.

8. **HIGH - Squeezer, pipeline, and aider are not apples-to-apples.**  
   Location: `bin/squeezer.py:247`, `bin/squeezer_pipeline.py:160`, `bin/cloud-run:221`, `bin/cloud-run:230`, `bin/cloud-run:246`  
   Single squeezer gets text tool-call fallback and temperature/seed forwarding; pipeline does not. Aider gets a different edit format, no comparable turn cap, and its cloud cost is forcibly written as zero. Pipeline “read-only” critics still have `run_bash`, which can write files.  
   Fix: define a harness contract: same prompt, same budget, same seed/temperature, same cost accounting, same filesystem limits, and recorded tool affordances.

9. **HIGH - Cloud setup semantics differ from local setup semantics.**  
   Location: `bin/eval-run:106`, `bin/eval-run:111`, `bin/cloud-run:186`, `bin/cloud-run:188`  
   Local `eval-run` lets `setup.sh` generate `workspace/prompt.md` and then uses it. `cloud-run` passes only one setup arg, ignores setup failure, and always uses `eval_dir/prompt.md`. Dynamic evals like needle/RAG are therefore not equivalent across venues.  
   Fix: pass both `<workspace> <eval-dir>`, check setup exit code, and prefer generated workspace prompts in cloud too.

10. **MEDIUM - Many rubrics reward hardcoding finite visible cases.**  
   Location: `evals/refactor/rubric.sh:31`, `evals/cli-tool/rubric.sh:23`, `evals/projectile-sim/rubric.sh:31`, `evals/projectile-sim/rubric.sh:69`, `evals/sql-injection-fix/rubric.sh:17`  
   Several rubrics check one exact output or static strings. A model can print the expected output, add `k1/k2/k3/k4` in comments, or fake placeholder usage without implementing the general task.  
   Fix: use seeded hidden cases plus reference oracles; remove static “implementation smell” bonuses or make them tiny guardrails.

11. **MEDIUM - Starter files leak the intended bug locations.**  
   Location: `evals/repo-bugfix-ledger/files/ledger/account.py:48`, `evals/repo-bugfix-ledger/files/ledger/posting.py:52`, `evals/repo-bugfix-ledger/files/ledger/report.py:32`  
   The ledger eval comments literally label BUG 1/2/3 and explain the fix. That measures following comments, not bug localization.  
   Fix: remove bug labels and explanations; provide failing behavior only through tests/spec.

12. **MEDIUM - Keyword medical/QA rubrics are unsafe and easy to game.**  
   Location: `evals/med-dose-pediatric/rubric.sh:22`, `evals/med-dose-pediatric/rubric.sh:30`, `evals/med-fever-pediatric/rubric.sh:23`, `evals/first-aid-triage/rubric.sh:3`, `evals/truthfulqa-mc/rubric.sh:3`  
   These score regex hits, not clinical correctness. `med-dose` can pass the critical ibuprofen check by merely saying “under 6 months ... ibuprofen” without negation. TruthfulQA’s rubric comment says 11/12 answers are A, and the prompt itself asks for one character despite 12 questions.  
   Fix: either remove non-coding/high-stakes QA from the coding leaderboard or use structured answer schemas with contradiction/negation checks and independent review.

13. **MEDIUM - `port-scanner` is environment-dependent.**  
   Location: `evals/port-scanner/rubric.sh:17`, `evals/port-scanner/rubric.sh:51`, `evals/port-scanner/rubric.sh:56`  
   It depends on live sockets, a “non-routable” IP timeout, local firewall/routing behavior, and port availability. Scores can change by host/network.  
   Fix: simulate socket outcomes or isolate in a controlled network namespace; otherwise tag and exclude it from headline means.

14. **MEDIUM - JSON score output is fragile.**  
   Location: `evals/bug-fix/rubric.sh:62`, `bin/cloud-run:65`, `bin/cloud-run:75`, `CLAUDE.md:145`  
   Rubrics hand-build JSON with unsafely interpolated notes; `cloud-run` then applies a lossy regex/strip fallback. This creates `score_pct: "?"` rows and silent data repair.  
   Fix: emit JSON using Python `json.dump` or a shared helper in every rubric.

15. **MEDIUM - Data schema is not reproducible enough.**  
   Location: `bin/cloud-run:261`, `bin/cloud-run:275`, `configs/cloud-arms.json:4`, `bin/cloud-report:42`  
   Single-model rows store only human labels, not actual model slug, provider route, config hash, prompt hash, rubric hash, git SHA, or suite version. Labels can drift and old rows remain comparable on paper.  
   Fix: persist immutable `model_id`, provider/backend, arm config hash, prompt/rubric/setup hashes, git SHA, suite version, and harness version.

16. **LOW - README/FINDINGS overclaim beyond the evidence.**  
   Location: `README.md:31`, `README.md:37`, `README.md:88`, `FINDINGS-CLOUD.md:64`, `FINDINGS-CLOUD.md:73`, `ROADMAP.md:37`  
   The docs claim same agent/tasks/scoring and reliable local-vs-cloud transfer while ROADMAP admits denominators differ. They cite confidence intervals as if already sound.  
   Fix: rewrite claims as provisional, remove “controlled” where the data is not paired, and publish only paired-suite results with valid uncertainty.

**Top 5 Things To Fix First**

1. Sandbox `run_bash` and make rubrics unreachable and immutable during agent execution.  
2. Fix denominator collapse in all import-error-skipping rubrics.  
3. Throw away and rerun the harness bake-off with tag-aware resume and paired cells.  
4. Replace cloud-report/dashboard aggregation with paired per-eval estimates and explicit failure handling.  
5. Add run metadata hashes/versioning so old rows cannot silently mix with new rubrics/configs.

**Verdict**

The headline claims are not currently trustworthy. The benchmark is useful as a prototype, but right now the agent can see the answer key, many rubrics can be reward-hacked or accidentally award 100 to stubs, and the published bake-off is not the controlled experiment it claims to be.