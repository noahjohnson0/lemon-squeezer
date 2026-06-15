# lemon-squeezer Roadmap

## Mission

lemon-squeezer exists to find **what actually gets real coding work done by open-weight LLMs as agents** - holding prompts and rubrics fixed while varying model × harness × config × venue, across a 12 GB consumer GPU and rented open weights on OpenRouter. The product of that research is two things outsiders can act on: an honest, statistically-defensible leaderboard, and a recommender that turns "given my GPU, budget, and privacy needs, what do I run?" into a copy-pasteable command. The identity is the squeeze, not any one model.

The current state of the repo has a credible *direction* but two structural cracks: the headline numbers rest on uncontrolled sampling and a median of one trial per cell, and the "same prompts, same venue-comparison" honesty claim is computed over **different task sets** locally vs. cloud. Everything below is ordered to fix the foundation before building on it.

---

## Product direction: the recommender (the front door)

It is all about **open weights** you can own or rent cheaply. The dashboard's headline should be a recommender, not a raw table:

- **Two competing tiles, both open models:** "Best on YOUR GPU" (the open model that fits your VRAM, its eval score, speed, watts) vs "Best open model in the cloud" (top open arm, its score, $/task). They compete on privacy vs cost vs quality; the visitor picks.
- **VRAM-tiered, not one answer.** "What should I run" is a function of VRAM (8 / 12 / 16 / 24 / 48 GB), because quality is venue-independent (measured once in the cloud) and fit is a lookup (model size at quant). So we can publish a tier table backed by real agentic-coding scores, not vibes.
- **Autodetect with override.** Read the GPU *name* via WebGL where the browser allows it, map to a VRAM tier, but default a dropdown the visitor controls (browsers do not expose VRAM).
- **Methodology consequence:** do quality / harness / mix testing in the CLOUD (parallel, cheap, high-n); use the local GPU only to confirm a model runs/fits and to measure speed + watts per tier. Cloud is ~2x the marginal cost per run but ~27x faster than serial local, so it is the right place to test.

---

## Now - fix the foundation (the numbers must be trustworthy before anything else ships)

These four make the existing data honest. Do not build the recommender, write blog posts, or add 20 evals on top of an estimator nobody can defend.

### 0. Integrity audit - 2026-06-15 (codex adversarial review)

An adversarial code review (OpenAI codex, high reasoning) plus a re-score pass closed the most damaging foundation cracks. Done:

- **Rubric denominator collapse (was CRITICAL).** 26 rubrics dropped their behavioral checks on an import error / mid-run exception, so a file that merely existed and compiled could score 100%. Proven: a `matops.py` of just `x = 1` scored 100%. All 26 rubrics were rewritten so every check always emits 0/1 (constant denominator); verified stub -> ~10%, correct -> 100%. All 2,894 affected runs were re-scored against the fixed rubrics with `bin/cloud-rescore`.
- **Uncontrolled bake-off.** `cloud-matrix`'s resume key ignored the tag, so a new bake-off skipped cells an old tag had already run (aider 154 vs squeezer 55, unpaired). Fixed: tag is now part of the resume key; `bin/bakeoff-report` only compares (eval, model) cells where **both** harnesses ran.
- **Answer leakage.** `repo-bugfix-ledger` labeled each bug in a comment (`# BUG 1 ...`); removed, so it is now a real localize-and-fix task.
- **Stats.** `cloud-report` rewritten: aggregate per eval first (trials are correlated), report the mean of per-eval means with a cluster bootstrap CI, and surface n_total / n_scored / n_failed. The dashboard switched from best-of-trials to per-cell means.
- **Broken rows.** `bin/clean-runs` removed 203 non-results / errored / phantom rows (with a backup + audit trail).
- **run_bash secret scrub + run_id uniqueness.** The agent shell no longer inherits API keys; run_ids carry a random suffix so same-second trials can't collide.

Still open (the honest gaps), incl. items from the codex re-verification (CODEX-VERIFY.md):

- **Real sandbox + a trusted verdict channel.** Two related holes: (1) `run_bash` runs in the repo tree, so a model could `cat` a rubric mid-run; (2) the rubric reads the submitted module's stdout to collect check verdicts, so an adversarial submission could `print("imports 1")` or `os._exit(0)` after forging all-pass lines and score 100. Neither is exploited by our (non-adversarial) models, but the fix is the same: run submitted code in a child process with its stdout captured SEPARATELY, and only accept verdict lines carrying a private rubric marker. Container/jail with only the workspace mounted.
- **Portable timeout in rubrics.** Rubrics call `gtimeout` directly (present here at `~/bin/gtimeout`, so current scores are correct) but it is absent on stock Linux CI; add a `TIMEOUT_BIN="$(command -v gtimeout || command -v timeout)"` resolver so they don't silently score correct solutions as static-only failures elsewhere. `matrix-ops` also needs an inner timeout. (Outer 120-180s backstops are now in `cloud-run`/`cloud-rescore`.)
- **Trim static freebies.** A few rubrics (e.g. base64-codec ~25%) still give an importable non-solution file+compile+no-stdlib credit; gate the no-stdlib bonus on at least one behavioral pass.
- **Standard external benchmark.** Run squeezer/aider on Aider-polyglot or SWE-bench-lite to put our numbers on the same ruler as everyone else's.

### 1. Pin sampling: temperature + seed on every run
**Why:** `squeezer.py`'s `call_chat` sends `{model, messages, tools, stream}` and nothing else - every result to date is at each provider's silent default temperature, so the bimodal `[0,100,100]` cells are *unrecorded* noise and "reproduce with `cloud-matrix`" is not actually reproducible.
**First step:** add `--temperature` (default 0.2) and `--seed` args to `squeezer.py` / `squeezer_pipeline.py`, put them in the request body, and persist them into `meta.json`.
**Effort/payoff:** S / **high** - root-cause fix; cheapest item on the board.

### 2. Report Wilson intervals + trial counts, not bare means
**Why:** a `100.0` from 1 trial and a `100.0` from 3 render identically in `cloud-report`; the deepseek-v4-flash (100) vs gpt-oss-120b (95) gap is ~one flipped run. Bare means imply precision the data doesn't have.
**First step:** in `cloud-report` `agg()`, compute n, pass-count, and a Wilson 95% CI per arm; sort by lower bound; print `mean% [lo-hi] n=K` and asterisk cells with n<3.
**Effort/payoff:** M / **high** - turns the leaderboard from a ranking into a defensible one; replace "single cheap model destroys Fable" prose with "a cluster of 4-5 arms is statistically tied."

### 3. One frozen suite manifest, shared by local and cloud
**Why:** the central honesty claim ("same tasks, different venue") is false today - 12 cloud-suite evals (every multi-file one, plus regex-engine, sudoku, etc.) have **never** run on the 4070, and 19 local-only evals aren't in the cloud suite. The "local 97 vs cloud 100" headline is computed over different denominators.
**First step:** create `configs/suite.json` (`{"version":"v2","evals":[{name, tier}...]}`) as the single source of truth; point `cloud-matrix` at it (it already reads `spec['suite']`) and add a `bin/suite-parity` check that diffs evals-run-on-4070 vs -on-openrouter and fails loudly when nonzero.
**Effort/payoff:** M / **high** - unblocks every cross-venue claim; do this *with* #2 so the first honest table lands together.

### 4. CI self-test: every rubric must score a known-good reference at 100
**Why:** some low scores are calibration bugs, not difficulty - port-scanner sits at 17.7% because its rubric needs a live network, marking correct scanners wrong and polluting every arm's mean equally. A rubric that can't pass a correct solution can't measure models.
**First step:** add a CI check that runs each eval's reference impl through its rubric and asserts `score==100`; start by auditing the bottom tier (port-scanner, sudoku, chem-balance, solar-position). Tag environment-dependent evals (`environment=network`) and exclude them from the headline mean.
**Effort/payoff:** M / **high** - this is the gate that keeps the suite honest as it grows; the CLAUDE.md stdout/JSON-corruption discipline becomes structural instead of folklore.

---

## Next - build on solid ground (expand the suite, fund the thesis, ship the front door)

### 5. Make multi-file "operate on an existing codebase" tasks the spine of the suite
**Why:** the algorithmic core is saturating (everyone clusters 88-97%) and is decades-old textbook material primed for memorization; the four multi-file evals added recently give the cleanest field separation (84-91%) **and** test the thing the platform claims to measure. This is the highest-signal, lowest-risk expansion - the pattern is already proven.
**First step:** template the existing four (starter `files/` package + `setup.sh` + rubric that imports the public API and runs hidden behavior checks); build the next 4 across the bug categories that separate the field (wrong-sign cross-module bug, drifted-copy refactor, feature-add into a CLI, stub-completion). Tag them `tier=multifile` with higher rubric ceilings so they dominate the signal.
**Effort/payoff:** L / **high** - the load-bearing direction. Build toward 15-20 total, but ship in batches of ~4 so each batch can be validated.

### 6. Split rubrics into visible vs. hidden checks + randomize inputs (anti-contamination + denser signal)
**Why:** two problems solved by one move. Prompts literally hand the model the acceptance values the rubric checks (`repo-bugfix-ledger` states `balance() == 70` and the rubric checks 70), so a model can spec-copy without generalizing. And all-or-nothing checks make each run a Bernoulli coin flip, forcing huge trial counts for a usable CI.
**First step:** for each rubric, separate VISIBLE checks (the few examples quoted in the prompt) from HIDDEN ones (more inputs the same logic must satisfy, never shown); for algorithmic evals, seed rubric inputs off `$LEMON_SEED` with a reference impl computing ground truth. Splitting one monolithic check into 5-10 graded sub-checks turns one draw into ~k draws and slashes the trials needed for the same CI.
**Effort/payoff:** L / **high** - measures generalization instead of copying *and* tightens every interval from #2. Note: this re-baselines scores, so re-run the canonical sweep once afterward under pinned sampling.

### 7. Fund the local (4070) side to cloud parity - it's the actual thesis, and it's starved
**Why:** the repo's identity is local-vs-cloud honesty, but there are ~2040 cloud rows vs. ~189 local, and **zero** local cells at ≥3 trials. The flagship "harness > model" finding rests on tiny local n, and the `pi` harness that produced it is barely in the current sweep.
**First step:** write `bin/local-matrix` (the resumable, trial-aware twin of `cloud-matrix`, serialized via the existing GPU lock) and define a fixed local matrix: small models (gpt-oss:20b, qwen3-coder:30b, qwen3:14b) × harnesses (squeezer, aider, pi) × the shared suite from #3, ≥3 trials, with temperature/seed captured (Ollama honors both). Grind it overnight via the `tourney<N>.sh` + nohup pattern.
**Effort/payoff:** L / **high** - without this the project's defining comparison is anecdotal.

### 8. Write FINDINGS-LOCAL.md from telemetry you already collected (+ a /local dashboard page)
**Why:** the cloud half has a findings doc, a leaderboard, and a dashboard page; the local half - the original mission - has only a stale FINDINGS.md. Yet 189 local rows already carry `gpu_mem_peak_mb`, `gpu_power_avg_w`, wall, and tokens - enough to compute the one result only a local rig can prove: **on a 12 GB card the active-param MoE wins on both quality and watts** (gpt-oss:20b ~40 W / ~11 GB / 95% via aider vs. dense qwen3:14b ~200 W for less). This is publishable *today, zero new GPU runs.*
**First step:** write `bin/local-report` (twin of `cloud-report`) emitting per-(model,harness) mean%, tokens/sec, avg W, energy Wh/task, VRAM peak, and a score-per-Wh metric; author FINDINGS-LOCAL.md around the MoE-on-12GB headline; add a static `/local` page mirroring `/cloud`.
**Effort/payoff:** M / **high** - best effort-to-impact ratio in the whole roadmap; turns thrown-away telemetry into the project's signature result. (Do this after #7 lands matched-n data, or ship the telemetry version now and refresh it.)

### 9. Ship the "Squeeze Picker" recommender (dashboard page + CLI)
**Why:** the dashboard answers "best combo in aggregate"; nobody answers the question an outsider actually has. All inputs already exist in `runs.jsonl` (`score_pct`, `cost_usd`, `wall_seconds`, `host`, `harness`, `model`) and `evals/CATEGORIES.md`. This is the single change that turns a research log into a tool people open.
**First step:** add a `/recommend` page with 4 inputs (privacy/venue, VRAM budget, $/task ceiling, task type) that filters arms by constraint and ranks by mean score on the matching eval subset (reuse the Bayesian shrink already in `Headline.tsx`), rendering the top pick as a copy-pasteable `cloud-run`/`eval-run` command plus receipts. Mirror as `lemon recommend --local --budget 0.002 --task algorithmic` over the same data.
**Effort/payoff:** M / **high** - the front door. Gated on #2/#3/#8 so the receipts it shows are honest. Encode the two owned findings as hard rules (prefer aider whole-file for sub-30B models; prefer active-param MoE when power-constrained).

### 10. Reframe the public narrative from "Fable destroyer" to "the squeeze"
**Why:** the export-control hook is dated and reads to a cold visitor as a time-boxed vendetta; the methodology is evergreen and the methodology is the value.
**First step:** rewrite the README lede as the model × harness × config × venue thesis, lead with the three transferable findings (harness > model; a cheap single beats clever mixes; reasoning/coding-specialist models underperform at agentic coding), demote the suspension date to a footnote, and add a "if you just want an answer, go to /recommend" paragraph. Rename FINDINGS-CLOUD.md's H1 to something durable.
**Effort/payoff:** S / **high** - cheap, and it's the framing the rest of the roadmap assumes.

---

## Later - higher-uncertainty bets and reach (do once the spine and front door exist)

### 11. Run the quantization sweep - the headline claim with no data behind it
**Why:** README/CLAUDE pitch quantization as a core axis and it's the most decision-relevant knob on a 12 GB card, but the data has exactly one explicit quant. Every telemetry field to make it rigorous is already wired.
**First step:** pull a quant ladder for 2-3 models (e.g. qwen2.5-coder:14b at q4/q5/q6/q8/fp16; the fp16 CPU-spill is itself a finding) and run them on the **hard-signal evals only** (regex-engine, matrix-ops, fft-spectrum, kalman-filter, knapsack, rate-limiter), 3 trials each, charting the quality-vs-VRAM-vs-tok/s "knee."
**Effort/payoff:** M / **high (deferred)** - feeds directly into the recommender's VRAM model; deferred only because it needs #7's local-matrix and the frozen suite first.

### 12. Add long-context and agentic-loop tiers with iteration as a measured axis
**Why:** the thesis is "what *finishes* agentic work," but most evals are 1-3 tool calls; `needle-haystack`/`wiki-full` ran locally only, and `squeezer.py` caps at ~20 iterations with no eval that requires deep loops - so "can this model sustain a 30-step debug loop" is unmeasured, which is exactly where weak local models break.
**First step:** promote needle-haystack/wiki-full into the shared manifest; add an agentic-loop tier (starter with a failing test suite + a stub; agent must run pytest, read failures, edit, re-run until green) with raised `--max-iter` and a bumped `run_bash` timeout; instrument `tool_calls`/`iterations` as a first-class reported axis and flag arms that hit the iter cap.
**Effort/payoff:** M / **med** - covers a real blind spot; lower priority than multi-file because it's heavier to build and grade.

### 13. SWE-bench-lite real-repo tier + a "vs public benchmarks" calibration page
**Why:** a self-built suite invites "is 100% on your dijkstra meaningful?" Anchoring to SWE-bench Verified / Aider polyglot (which test the same open models) lets readers map the harness-effect insight onto numbers they already believe, and real-repo tasks have near-zero memorization.
**First step:** stand up 5-10 pinned-commit bugs from a tiny real OSS Python lib (each a `files/` snapshot + the upstream failing test as the hidden rubric, scored purely on "does the upstream suite pass"); add a static, cited reference table of the same models' public scores and plot lemon-squeezer mean% against them.
**Effort/payoff:** L / **med** - strongest credibility move, but the most work; the multi-file tier (#5) buys most of the same anti-contamination value sooner.

### 14. Auto-generated per-finding cards + a low-friction contribution path
**Why:** insight currently lives in two long markdown files an outsider can't link, screenshot, or cite; and a leaderboard others can submit to is the difference between a personal project and a community resource - achievable via PRs without violating the static-no-backend rule.
**First step:** have `eval-export` emit `findings.json` (id, claim, query, prose) and add a `/findings/[id]` route rendering one self-contained card with a "reproduce with" command; add CONTRIBUTING.md with two recipes ("add an eval", "submit results via PR") plus a GitHub Action that re-runs `eval-rescore` on submitted rows rather than trusting them.
**Effort/payoff:** M / **med** - reach and community; do after the findings are stable so cards don't churn.

### 15. LLM-judge-graded open-ended tier (with a deterministic floor) + speculative decoding spike
**Why (judge):** every rubric is deterministic IO checking - a strength to preserve, but it excludes open-ended work (clean API, readable refactor, useful docs) where models genuinely differ. **Why (spec-decode):** local's worst axis vs cloud is throughput; speculative decoding raises tok/s without touching quality - exactly the "squeeze."
**First step (judge):** add a judge harness emitting a deterministic floor (runs/compiles/smoke-passes) PLUS a judge-graded quality component; **pin the exact judge model id + system prompt in the manifest, record it per-run, and validate against ~30 hand-labels before shipping** (report the agreement number). The judge must never be one of the arms under test, and scoring must be blind. **First step (spec-decode):** confirm whether the 4070S Ollama build exposes a draft-model option; if not, run via llama.cpp `--model-draft` against the same OpenAI-compatible endpoint squeezer already speaks, pairing a verifier+drafter that co-fit in 12 GB.
**Effort/payoff:** L / **med** - both are genuinely uncertain (judge agreement may be low; Ollama spec-decode support is version-dependent), so scope each as a spike with a clear kill criterion.

---

## Open research questions

- **Does the harness > model finding survive matched n + CIs?** Quantify it as a number: "switching squeezer→aider moves mean +X pp [CI] vs. best-vs-worst model +Y pp."
- **Where is the quantization knee on a 12 GB card?** Specifically, is q5 of a 30B-MoE ever worth its VRAM over q4, and does fp16 CPU-spill ever buy back points (hypothesis: never on a 4070)?
- **Can a large-but-sparse MoE "punch above 12 GB" via CPU/GPU offload** - and at what tok/s tax?
- **Does the cloud mix-as-rescue pattern (69%→92%) replicate locally** on a 14B model wrapped in verify/critique, and at what energy cost?
- **Held-out vs spec-given:** how much does score drop when the rubric's checked values are hidden from the prompt? (A direct measure of memorization/spec-copying.)
- **Does score correlate with tool_calls/iterations**, and which arms finish in 3 calls vs. flail to the iter cap?
- **Does OpenRouter's silent backend/quant routing introduce trial-to-trial variance** large enough to matter once sampling is pinned?

---

## Guardrails - what keeps the findings honest

- **No bare means, ever.** Every leaderboard number ships with n and a Wilson interval; rankings sort by lower bound. When intervals overlap, say "statistically tied," not "X beats Y."
- **Sampling is pinned and recorded.** temperature/seed/top_p in every request body and every `meta.json`. Old provider-default runs are footnoted, never silently mixed with pinned ones.
- **One frozen suite manifest gates cross-venue claims.** `bin/suite-parity` fails CI when the local and cloud denominators diverge; "same task, different venue" is enforced, not asserted.
- **Every rubric passes its own reference at 100% in CI.** A rubric that can't score a correct solution can't enter the suite. Environment-dependent evals (network, etc.) are tagged and excluded from the headline mean.
- **Visible vs. hidden checks** keep the suite measuring generalization, not spec-copying; randomized seeded inputs keep memorized literals from passing.
- **Per-tier leaderboards** so saturated easy evals stop diluting hard-task signal - report algorithmic / multifile / longctx / agentic separately.
- **Rubric changes force a re-baseline.** When checks change, the canonical sweep is re-run; never compare scores across rubric versions.
- **The judge is an instrument under test, not an oracle** - pinned model id, blind scoring, never an arm under test, and shipped only after measured human agreement (reported in FINDINGS).
- **Cost/energy claims get dispersion too.** Report cost/latency with IQR and score-per-$ via bootstrap CI (not ratio-of-means); surface energy Wh/task as the local cost axis, and capture OpenRouter's backend field so routing variance is visible.
- **A REPRODUCE.md pins the world:** arms-file hash, suite version, temperature/seed set, trials, date, total spend - so "reproduce with cloud-matrix" is actually deterministic-enough to re-derive the intervals.
- **Negative results are published.** Honest zeros (cline times out on sub-frontier models; a mix that lost) beat cherry-picked wins.
