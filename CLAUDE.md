# Claude operating manual for `lemon-squeezer`

This file is project-local guidance for any AI agent working in this repo. Read it
before making changes — it captures conventions and gotchas that aren't obvious
from the code alone.

## What this repo is

A reproducible benchmark for **local-LLM coding agents** on consumer GPUs. We
test combinations of `(harness, model, eval, config, host)` and surface the
findings on a static dashboard. The point is to figure out what local
combination actually completes real-world coding tasks.

## Anatomy

```
bin/
  eval-run                   # canonical entry point — see Run Lifecycle below
  eval-export                # rebuild runs.jsonl/csv/RUNS.md/findings.md from per-run meta.json
  eval-rescore               # re-derive score_pct from each run's score.json (or re-run rubric)
  eval-list / eval-diff      # CLI reporting helpers
  serve                      # local HTTP server + auto-launches inflight-watcher
  inflight-watcher           # writes inflight.json every ~2s for the live dashboard panel
  sampler                    # per-run telemetry start/stop; nvidia-smi over SSH or local Mac
  squeezer.py                # raw single-pass tool-calling agent (read/write/list/bash)
  squeezer_pipeline.py       # multi-step orchestrator (critique / ensemble / architect / verify)
  squeezer_search.py         # squeezer + search_docs/web_search retrieval tools
  librarian.py               # RAG agent: search_local + read_local + write_answer
  refs/build_index.py        # build SQLite FTS5 index over a corpus directory
  refs/search.py             # FTS5 query over .lemon-index.db
  lemon                      # daily-driver CLI: ask | code | librarian | search | route | corpora
  harnesses/                 # one .sh shim per harness, exporting harness_run()
evals/<name>/
  prompt.md                  # the natural-language task
  rubric.sh                  # runs the produced code, emits {checks, gained, total, score_pct} JSON
  setup.sh                   # OPTIONAL — drops starter files into the workspace
  files/                     # OPTIONAL — starter file dir
configs/                     # system-prompt augments (--read'd by aider, --system'd by squeezer)
hosts/                       # per-machine env profiles (4070.env, m4max.env)
runs/<run_id>/               # one dir per run: workspace + meta.json + score.json + metrics.csv + logs
dashboard-next/              # Next.js static export, deployed to GitHub Pages
```

## Run lifecycle (`bin/eval-run`)

```
eval-run [--host <name>] <harness> <eval> <model> <tag> [-- harness-flags...]
```

1. Source `~/.config/lemon-squeezer.env` if present (local secrets — gitignored).
2. If `--host <name>` given, source `hosts/<name>.env` (sets `OLLAMA_API_BASE`,
   `SAMPLER_SSH_TARGET`, `LEMON_HOST`).
3. Register a pending entry in `pending/<pid>/info` (visible to inflight-watcher).
4. Acquire **GPU lock** (`mkdir .gpu.lock`) — atomic, blocks while held by
   another `eval-run`. Stale lock is reclaimed if owner pid is dead. Set
   `LEMON_NO_LOCK=1` to bypass (don't, unless on a different host).
5. Compute `RUN_ID = <ts>_<eval>_<harness>_<safe-model>_<tag>`, mkdir
   `runs/<run_id>/workspace`. Drop `.model` and `.tag` markers (originals).
6. Optional `setup.sh` populates the workspace.
7. Start telemetry sampler (background; writes `metrics.csv`).
8. Run harness wrapped in `gtimeout` (default 600s, pipelines 1800s, override
   via `LEMON_RUN_TIMEOUT` / `LEMON_PIPELINE_TIMEOUT`).
9. Run rubric → `score.json`. Parse `score_pct`.
10. Write `meta.json` with score, tokens, wall, host, etc.
11. Stop sampler (it appends `meta.telemetry.*` aggregates).
12. Append `meta.json` to `runs.jsonl`, run `eval-export` to refresh
    `runs.csv`, `RUNS.md`, and `dashboard-next/public/findings.md`.

## Cloud runs (OpenRouter) — the local lifecycle's twin

`bin/cloud-run` is the cloud counterpart of `eval-run`: same prompts, same
rubrics, but it drives an **open-weight model rented on OpenRouter** instead of
local Ollama. No GPU, no lock, no telemetry — a cloud run is just HTTP + local
rubric scoring, so it's safe to parallelise and runs fine on the Windows box.

```
# single open model:
bin/cloud-run <eval> <openrouter/slug> [tag]
# a multi-model MIX (squeezer_pipeline under the hood):
bin/cloud-run <eval> --pipeline architect|critique|ensemble|verify \
    --primary-model <slug> [--architect-model/--critic-model/--judge-model <slug>]
```

Rows are tagged `host="openrouter"`; mix rows carry a `mix` object and a readable
`model` label (e.g. `arch:30b<-pro`). Cost (`cost_usd`) comes from OpenRouter's
per-call `usage.cost`. Auth: `$OPENROUTER_API_KEY` (or `$LEMON_API_KEY`).

**The whole experiment** is driven by `bin/cloud-matrix`: every arm in
`configs/cloud-arms.json` (singles + mixes) × the eval suite × N trials, run in
parallel with a **single safe writer** to `runs.jsonl` and a **hard USD budget
cap**. It's round-robin ordered (a budget cut-off still leaves a complete
cross-arm comparison on a prefix of the suite) and **resumable** (skips cells
that already have `trials` rows). Analyse with `bin/cloud-report`.

```
bin/cloud-matrix --trials 3 --budget 9 --concurrency 8 --tag fable-hunt
bin/cloud-report --tag fable-hunt --by-eval
```

Windows gotchas already handled in `cloud-run`: eval `setup.sh`/`rubric.sh` are
fed to `bash -s` on stdin with CRLF stripped, and the workspace is passed as a
**ROOT-relative POSIX path** (drive-letter `C:/...` paths don't resolve in MSYS
bash `[[ -f ]]` tests). Don't "fix" these back to plain `bash script.sh "$WS"`.

## Adding a new eval

```
mkdir evals/<name>/
$EDITOR evals/<name>/prompt.md   # task description
$EDITOR evals/<name>/rubric.sh   # see ANY existing rubric for the boilerplate
chmod +x evals/<name>/rubric.sh
```

Self-test it before committing — write a known-good reference impl in `/tmp/`
and run the rubric against it; aim for 100% on the reference. Pattern:

```
mkdir /tmp/x && cat > /tmp/x/<file>.py <<'PY'
... reference impl ...
PY
bash evals/<name>/rubric.sh /tmp/x | python3 -c "
import json,sys,re;m=re.search(r'\{[\s\S]+\}\s*$', sys.stdin.read())
d=json.loads(m.group(0));print(f\"{d['score_pct']}% ({d['gained']}/{d['total']})\")"
```

## Adding a new harness

```
$EDITOR bin/harnesses/<name>.sh   # define harness_run() — see existing shims
chmod +x bin/harnesses/<name>.sh
```

The function signature is fixed:

```bash
harness_run() {
  local ws="$1" prompt_file="$2" model="$3" run_dir="$4"; shift 4
  # ... call your CLI ...
  # MUST write to $run_dir: tokens_in, tokens_out, tool_calls (one number per file)
}
```

## Rubric gotchas (DO NOT FORGET THESE)

1. **Stdout vs stderr.** The rubric's stdout becomes `score.json`. ANY `echo`,
   `print`, `python3 -c "print(...)"` outside of the final emit block must be
   redirected to stderr (`>&2`) or the JSON is corrupted. We literally lost
   12 chem-balance scores to this; the eval-export auto-runs `eval-rescore`
   which has an `\x`/`\0`-stripping fallback parser, but don't rely on that.
2. **Backslashes AND double-quotes in notes.** Notes like `got=b'\x00'` from
   `repr()` produce invalid JSON escapes; notes containing `"` (e.g. from
   `NameError("name 'EOF' is not defined")`) break the JSON entirely.
   The `add()` helper takes a raw string into a printf `%s`; sanitize the
   note before storing — at minimum strip backslashes and replace `"` with
   `'`, or just don't pipe `repr()` exception messages straight into notes.
   robot-arm-ik hit this with a gpt-oss:20b run that emitted a literal
   `EOF` line; the import error message contained a quote and the score.json
   wouldn't parse. `eval-rescore` has a stripper fallback but trust nothing.
3. **`gtimeout`.** macOS doesn't ship `timeout(1)` — we use `gtimeout` from
   `coreutils`. `brew install coreutils` is a hard dep. Linux CI gets the
   `timeout` fallback in `bin/eval-run`.
4. **Empty/skipped checks.** Always `add` every check even when a precondition
   fails (e.g. file missing). The Bayesian rank in the dashboard assumes a
   constant denominator per eval.
5. **`set -u` and empty arrays.** Use `${ARRAY[@]+"${ARRAY[@]}"}` not
   `"${ARRAY[@]}"` for arrays that might be empty. We hit "unbound variable"
   here at least twice.

## Aider's nested .git problem

`aider` does `git init -q` inside every workspace it edits, leaving a `.git/`
in `runs/<run_id>/workspace/`. When the OUTER repo tries `git add -A`, those
nested repos are flagged as "does not have a commit checked out" and the add
aborts. Always run this before commits:

```bash
find runs -mindepth 3 -name '.git' -type d -exec rm -rf {} + 2>/dev/null
```

Already in `.gitignore` for new ones (`runs/**/workspace/.git/`) but old runs
predate that rule.

## Hosts and telemetry

The sampler runs locally on the orchestrator (the Mac). For remote NVIDIA
hosts (the Windows 4070), it `ssh`s `nvidia-smi --query-gpu=...` once per
second. SSH multiplexing was tried and broken (the `-fN` daemon refused to
start in a redirected-fd subshell); now using a fresh handshake per sample —
ugly but reliable. Don't waste time re-trying multiplexing without a careful
end-to-end smoke test.

For Mac (M4 Max) hosts, `nvidia-smi` doesn't exist. The sampler detects
`uname -s == Darwin` and instead captures `host_cpu_pct` (parsed from `top`),
`host_mem_used_pct` (computed from `vm_stat`), and `ollama_rss_mb` (from
`ps`). Both branches write into the SAME csv schema; absent columns are just
empty. The dashboard handles both.

## GPU lock

`.gpu.lock/` is the serialization mutex. Only ONE eval-run holds it at a time.
Multiple invocations queue (visible as `pending/<pid>/info` to the dashboard).
Without this, concurrent runs share Ollama's queue → wall-time and per-second
telemetry attribution become meaningless. The lock is the difference between
a benchmark and a guess.

## Dashboard rules

- It's a Next.js 16 static export (`output: 'export'`) at `dashboard-next/`.
  `next build` writes `dashboard-next/out/` which the GH Pages workflow
  publishes as `noahjohnson0.github.io/lemon-squeezer/`.
- Reads ONLY `./runs.jsonl` and `./inflight.json` (relative). Both files are
  symlinks at dev-time (`public/<name>` → `../../<name>`); the GH workflow
  copies the resolved files in at build time.
- `inflight.json` is treated as ephemeral. If older than 30s, the live panel
  hides itself, so a missing watcher doesn't break the page.
- NO external API calls at runtime. Static-only.
- DO NOT reintroduce a server. The dashboard must keep working when checked
  into GH Pages with no backend.

## Memory locations the dashboard reads

```
runs.jsonl                       # one Run object per line
runs/<id>/score.json             # check-by-check breakdown (drawer fetches on demand)
runs/<id>/metrics.csv            # 1-Hz time series (drawer fetches on demand)
inflight.json                    # current running + queued; refreshes every 2s
dashboard-next/public/findings.md  # auto-regenerated by eval-export
```

## Things that have come up and bitten me

- The `eval-rescore` exit-code logic: `python -c '...; sys.exit(10)'` returns
  10, but `cmd && a || b` treats ANY non-zero as failure. Use `case "$rc"`.
- The `--append-system-prompt` flag was added late to pi; configs that use it
  may not work for older pi versions.
- `score_pct: "?"` placeholders happen when score.json fails to parse. Run
  `bin/eval-rescore` and the file usually heals.
- Cline as a harness: it has a CLI now (`npm i -g cline`) but expects models
  trained on its XML tool-call format. Local 14B models tend to time out
  rather than produce tool calls. If you add cline as a harness, expect lots
  of zeroes for non-frontier-class models and document that.
- Aider's `--read` has a basePath quirk on Pages — pass relative paths only.

## Offline-local stack (RAG + retrieval tools)

The point of this stack is to make the 4070 actually useful for daily local
work — coding with cached docs as ground truth, factual Q&A grounded in
references, no cloud round-trips.

**Corpora live at `~/refs/<name>/`** on the Mac orchestrator (and on the
Windows box at `D:\refs\<name>\` — there's 931 GB free on D:). Each corpus is
a directory of `.md` / `.txt` / `.rst` plus a `.lemon-index.db` SQLite FTS5
index built by `bin/refs/build_index.py`. Build once, query many times via
`bin/refs/search.py` or via the agent tool `search_local`.

**Two new harnesses use this:**
- `librarian` — single-purpose RAG Q&A agent (`bin/librarian.py`). Tools:
  `search_local`, `read_local`, `web_search` (gated on `$LEMON_ALLOW_WEB=1`),
  `write_answer` (terminates the loop). Pass corpora via `$LEMON_CORPORA` as
  colon-separated `name=path` pairs. If `workspace/context/` exists, an
  index is built on-the-fly into a corpus named `context` — that's how
  `wiki-rag-tool` works without external corpora.
- `squeezer-search` — squeezer's coding tools (`read_file`/`write_file`/
  `list_files`/`run_bash`) PLUS `search_docs` and (optional) `web_search`.
  Tests whether grounding helps coding evals.

**`bin/lemon`** is a daily-driver wrapper:
```
lemon corpora                        # list registered corpora + their stats
lemon search lemon-test "query"      # raw FTS5 search, no LLM
lemon route "question..."            # show which model+harness would be picked
lemon ask "question..."  [--web]     # one-shot librarian Q&A
lemon code "task..."     [--web]     # squeezer (or squeezer-search) coding
```
The router is a heuristic — verbs like "refactor"/"debug"/"implement" and
language tokens like "python"/"sql" route to `code:$LEMON_CODE_MODEL`;
everything else routes to `librarian:$LEMON_LIBRARIAN_MODEL`.

**Eval `wiki-rag-tool`** is the librarian counterpart of `wiki-rag`. Same
questions, same corpus — but instead of pre-loading the articles into the
system prompt, the agent must `search_local` for them. The rubric scores
both correctness AND tool usage (≥2 search calls).

## When the user says "go", "run more", "fill the matrix"

Their default mental model: queue more `eval-run` invocations against the
4070 (host=4070, the Windows box), serialise via the GPU lock. The output
fills `runs/`, `runs.jsonl` updates, dashboard auto-refreshes. Use
`tourney<N>.sh` scripts under `/tmp/` for batches, `nohup` + `disown` so the
batch survives shell exits.

When they say "M4 Max", point eval-run at `--host m4max`. Don't run M4 evals
without explicit go-ahead — pulls fine, scoring not.
