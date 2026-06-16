**Findings**

CRITICAL - `dashboard-next/src/app/orchestration/page.tsx:50`  
The page fetches `../runs.jsonl`, which in static export resolves to `dashboard-next/public/runs.jsonl`, not the canonical root `runs.jsonl` used by `bin/cloud-report`. The public copy is stale: root has 4,654 lines / 3,852 `fable-hunt` OpenRouter rows; public has 3,895 lines / 3,213 rows. This changes the displayed best single from canonical `deepseek-v4-pro` to stale-data `glm-5.1`.  
Fix: make the dashboard build sync root `runs.jsonl` into `public/` before export, or generate a versioned JSON artifact from the canonical aggregation and fetch that.

HIGH - `dashboard-next/src/app/orchestration/page.tsx:54`  
The page includes `port-scanner`, but `bin/cloud-report:40-44` and `bin/cloud-report:61` exclude it from headline aggregates unless `--include-env` is passed. This lowers all headline scores and means the page does not match the canonical “main suite” math. On root data, canonical best single is `99.4%`; page-style including env is `97.5%`.  
Fix: share an excluded-evals constant or filter `r.eval !== "port-scanner"` in the page aggregation.

HIGH - `dashboard-next/src/components/OrchestrationFlow.tsx:39-68`, `:74-80`  
Two-node cyclic patterns collapse. For `critique` and `verify`, the relaxation loop assigns both nodes the same level, so both nodes have the same x coordinate and overlap vertically by about 2.6px. Both edges are then drawn “backward” from x=614 to x=482 through the node boxes.  
Fix: detect reciprocal edges/SCCs and lay 2-node cycles left/right with a separately routed return edge, or hard-code cycle layouts for `critique` and `verify`.

HIGH - `dashboard-next/src/app/orchestration/page.tsx:35-41`, `:84-86`, `:69-71`  
The page renders `swarm` as a pattern alongside measured harnesses, but current data/config have no `cloud-swarm` rows. The text says lemon-squeezer “runs four such patterns as harnesses,” while the UI shows five patterns and makes swarm look part of the measured suite.  
Fix: either remove swarm from the scored pattern grid, label it explicitly as conceptual/unscored, or add a real `cloud-swarm` harness and rows.

MEDIUM - `dashboard-next/src/app/orchestration/page.tsx:68`, compared with `bin/cloud-report:127-129`  
The page chooses “best” by raw mean score only. `cloud-report` orders sufficient arms by CI lower bound, then mean cost. Current top picks happen to align, but the method does not match the canonical rank semantics and can flip on close arms.  
Fix: either import/use a canonical precomputed leaderboard, or compute bootstrap CI/lower-bound rank in the same place as `cloud-report`.

MEDIUM - `dashboard-next/src/app/orchestration/page.tsx:50`, `:95-117`  
Fetch failures and empty data are swallowed. If `runs.jsonl` 404s under static export, the page silently shows diagrams and claims but no verdict, making data absence look intentional.  
Fix: track `loading/error/loaded` state and render an explicit “results unavailable” or “loading runs” state.

MEDIUM - `dashboard-next/src/components/ConductorPanel.tsx:26`  
`animate-ping` ignores `prefers-reduced-motion`. `OrchestrationFlow` mostly handles reduced motion, but this panel still runs an infinite animation.  
Fix: gate the ping class with a reduced-motion hook or Tailwind’s `motion-safe:` variant.

LOW - `dashboard-next/src/app/orchestration/page.tsx:137-140`  
The arXiv IDs are real, but some framings are loose. ReAct is not specifically an architect/verify pattern; Self-Consistency is consensus over sampled reasoning paths, while this ensemble is “judge picks best”; AutoGen supports multi-agent conversation but does not specifically imply disjoint parallel swarm integration.  
Fix: soften labels to “related ideas” rather than “where these patterns come from,” or cite pattern-specific implementations.

LOW - `dashboard-next/src/app/orchestration/page.tsx:158`  
“OpenAI Swarm” is listed as a current framework without caveat. The repo itself says Swarm is experimental/educational and replaced by the OpenAI Agents SDK for production use.  
Fix: label it “OpenAI Swarm, educational/deprecated” or replace/add Agents SDK.

Reference checks: the arXiv IDs for ReAct, Self-Refine, Self-Consistency, AutoGen, OpenHands, and SWE-agent resolve as claimed; OpenAI Swarm’s repo states it is replaced by Agents SDK.