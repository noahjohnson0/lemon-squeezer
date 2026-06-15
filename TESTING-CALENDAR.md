# Testing Calendar

What we are running, in what order, with rough time and cost. Cost is API dollars
for cloud and electricity (kWh, at your $/kWh) for local. Rates below are measured:
cloud burns ~$0.013/run and ~$0.2-0.4/min wall at concurrency 32; local runs are
serial on the single GPU at ~30-120 s each and ~0.1-0.8 kWh per model-suite.

Status legend: [run] running now, [next] queued, [later] after foundation work.

## In flight

| # | Batch | What it answers | Time | Cost |
|---|---|---|---|---|
| [run] | Cloud sweep v3 | 39 arms x 40 evals x ~4 trials, incl. multi-file evals | ~3-5 h | ~$55 more (to ~$95 of the $100 cap) |
| [run] | Local 4070 sweep | 3 tool-capable coders x 16-eval shared suite (parity with cloud) | ~1-2 h | ~0.5 kWh |

## Next (this week)

| # | Batch | What it answers | Time | Cost |
|---|---|---|---|---|
| 1 | **Harness bake-off** | squeezer vs aider vs pi on the SAME local models x shared suite. Settles "is squeezer actually good." | ~2-4 h (serial, GPU) | ~1 kWh |
| 2 | **Foundation fixes** | pin temperature+seed; Wilson intervals + trial counts in reports; one frozen suite manifest shared local+cloud; CI rubric self-tests. Code, not runs. | ~2-3 h | $0 |
| 3 | **Re-run canonical sweep** | redo the headline cloud + local rows under pinned sampling so numbers are reproducible | ~3 h | ~$25 cloud + ~1 kWh |
| 4 | **More multi-file evals** | 4-8 more "operate on an existing codebase" tasks (the highest-signal kind) | ~30 min author + folds into sweeps | author $0, runs ~$10 |

## Later (needs setup or budget)

| # | Batch | What it answers | Time | Cost |
|---|---|---|---|---|
| 5 | **Standard external benchmark** | top arms on aider-polyglot / SWE-bench-lite, to kill home-field bias | ~half day | ~$10-30 cloud |
| 6 | **M4 Max 48 GB venue** | what a 48 GB unified-memory Mac unlocks (70B-class local models the 4070 can't hold) | ~half day | electricity (Mac) |
| 7 | **Local sweep to parity** | more local models x harnesses x shared suite at >=3 trials each (the local side is currently thin vs cloud) | overnight | ~2-3 kWh |
| 8 | **Scaled cloud sweep** | when budget is raised: more arms, more trials, tighter intervals | budget-bound | up to new $ cap |

## Notes

- Cloud is parallel and budget-capped (`bin/cloud-matrix --budget`), so its cost is
  bounded and its wall-time scales with concurrency. Local is serial on one GPU, so
  its wall-time is the real constraint there, not money.
- Electricity is estimated by `bin/energy-report` (most historical local runs carry
  measured GPU power; the rest use a tunable whole-system wattage). Set `--price` to
  your utility rate for a real bill figure.
- Every batch appends to `runs.jsonl` and is resumable, so any of these can be
  paused and continued without losing work.
