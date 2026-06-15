**10-Second Verdict**

This helps the candidate only after the reader slows down. In the first 10 seconds, it risks underselling the work.

The eye lands on “How much can you squeeze out of an LLM?” and the giant model name/leaderboard. That says “cool benchmark toy” before it says “serious reproducible agentic-coding evaluation system.” The screenshots look polished and data-rich, but the core accomplishment is not instantly legible: controlled experiments over `model × harness × config × venue`, scored by executing generated code, with cost/local/cloud tradeoffs.

A busy hiring manager might keep scrolling because the page looks substantial. A skeptical staff engineer may bounce or discount it because the headline is cute, some claims are under-explained, and the most rigorous parts are buried.

**Hire-Signal Read**

Net: positive, but weaker than it should be. The project itself signals strong full-stack + AI systems judgment: benchmark design, dashboards, cost accounting, local/cloud infrastructure, reproducibility, and statistical caution. The public page currently signals “enthusiast leaderboard” before “engineer who can build rigorous evaluation infrastructure.”

The fix is mostly framing, not substance.

**Critical Changes**

1. **Hero headline**
   Current: “How much can you squeeze out of an LLM?”

   Problem: Memorable, but vague. It does not say coding agents, open-weight models, reproducible benchmark, or why this matters.

   Rewrite:
   “Which open-weight LLM coding agents actually finish real tasks?”

   Or:
   “A reproducible benchmark for open-weight coding agents”

2. **Hero mission**
   Current: “A reproducible study of what actually makes an LLM finish real coding work...”

   Better, but still too wordy and slow. The strongest sentence should be above the fold.

   Rewrite:
   “lemon-squeezer tests open-weight LLM coding agents across model, harness, config, and venue, then scores them by running the code they produce.”

3. **Above-the-fold takeaway**
   Current first major card says: “Best combo overall deepseek-v4-flash via aider-cloud on openrouter.”

   Problem: This answers a narrow leaderboard question before explaining the project. A hiring manager needs “what was built?” before “who won?”

   Redesign:
   Put a three-item findings strip above or inside the first card:
   - Harness choice can move scores by 50+ points on the same model.
   - Cheap open models reach the high-90s on this suite for fractions of a cent per task.
   - Local GPU vs cloud is measured with cost, latency, VRAM, and score.

4. **Cloud page framing**
   Current: “How much can open models squeeze out?” and “Fable 5 being unavailable... the point is the squeeze, not the kill.”

   Problem: “squeeze,” “kill,” and Fable context read like inside-baseball drama. It weakens professional credibility.

   Rewrite:
   “How close do open-weight coding agents get to frontier performance?”
   Body:
   “This page compares rented open-weight models and multi-model mixes on the same coding-agent evals, reporting score, cost per task, latency, and trial count.”

5. **Rigor claim needs a methodology link near the top**
   Current: GitHub link exists, but no visible “Methodology / Reproduce / Data” affordance.

   Add top-level links:
   `Methodology`, `Reproduce`, `Raw runs`, `GitHub`.

   Hiring managers and staff engineers should not have to infer that `runs.jsonl`, rubrics, and commands exist.

**High-Priority Changes**

6. **Replace cute chips with evidence chips**
   Current:
   “harness often beats model”
   “mixes rescue weak models”
   “reasoning ≠ coding”
   “a 4070 gets ~97%”

   Problem: The first three are good but casual. “a 4070 gets ~97%” is dangerously underqualified.

   Rewrite:
   - `4,551 scored runs`
   - `40 deterministic coding evals`
   - `model × harness × config × venue`
   - `score = executed code`
   - `cost + latency tracked`

7. **Clarify the recommender audience**
   Current: “What should you run?” / “Best on your GPU”

   Problem: Good section, but it does not immediately say “for coding-agent tasks under this benchmark.” Also, local quality is derived from cloud quality with a footnote. That is easy to misread.

   Rewrite heading:
   “Recommended open-weight coding agent setup”

   Tile labels:
   - “Best fit for your VRAM”
   - “Best rented open-weight model”

   Add inline caveat:
   “Local score is estimated from cloud precision; measured q4 local runs are typically 3-5 points lower.”

8. **Tighten statistical language**
   Good signals: “Bayesian-shrunk avg,” `n`, confidence intervals, cost per task, score-per-dollar.

   Problem: Some numbers are unexplained or look precise without enough context. “95% CI 61+” is unclear. “Bayesian-shrunk” is rigorous but recruiter-hostile.

   Rewrite:
   “Rank-adjusted score: penalizes low-sample rows so one lucky run cannot top the table.”

   Show:
   `mean 98% · 95% CI 94-100 · n=101 · $0.0028/task`

9. **Reduce leaderboard intimidation**
   Problem: The home leaderboard is impressive but visually dense. The screenshot’s table dominates before the reader knows what to look for.

   Redesign:
   Add a “Key findings” block before the table. Keep the table, but make it supporting evidence, not the first conceptual explanation.

10. **Professionalize visual tone**
   Problem areas: lemon emoji logo, medal emojis, crown emoji, “TL;DR,” “pennies per task,” “not vibes,” “the kill.”

   These are not fatal, but together they make the project feel less senior. Keep personality in the repo; make the portfolio page more restrained.

   Replace:
   - “TL;DR” → “Recommendation”
   - “not vibes” → “not subjective judging”
   - “pennies per task” → “low API cost per task”
   - emojis in rank rows → plain `#1`, `#2`, `#3`

**Medium-Priority Changes**

11. **Add an About / Author block**
   Missing: who built this, why, what role it demonstrates.

   Add:
   “Built by Noah Johnson as an open evaluation harness for open-weight coding agents. Includes runner, eval suite, cloud/local orchestration, raw run logs, and dashboard.”

12. **Add “How it works” near the top**
   Current docs explain this well, but the dashboard does not.

   Pasteable structure:
   `Prompt + starter files → agent harness → generated code → rubric.sh → score_pct → runs.jsonl → dashboard`

13. **Rename nav item “RAG”**
   Problem: In the screenshots, `RAG` appears unexplained and unrelated to the visible benchmark. It distracts from the main project.

   If it is experimental, move it later or label it clearly:
   `Benchmarks`, `Cloud`, `RAG Eval` only if relevant.

14. **Make “live” meaningful**
   Screenshot shows “idle” while hero says “scored runs · live.” That reads inconsistent.

   Use:
   `4,551 scored runs`
   `Last run: Jun 15, 2026`
   `Auto-refreshing`

**Hero Options**

Option 1:
Headline: “Which open-weight coding agents actually finish the work?”
Mission: “lemon-squeezer is a reproducible benchmark that tests model × harness × config × venue and scores each run by executing the code the agent produced.”

Option 2:
Headline: “A reproducible benchmark for open-weight LLM coding agents”
Mission: “It compares local and cloud open-weight models on real coding tasks, with trial counts, confidence intervals, cost per result, and VRAM-aware recommendations.”

Option 3:
Headline: “Find the best open-weight coding-agent setup for your GPU or budget”
Mission: “lemon-squeezer measures which combinations of model, harness, and venue complete coding evals most reliably per dollar, watt, and GB of VRAM.”

**Plain-English Key Findings Block**

Paste this near the top:

> **Key findings**
>
> We ran 4,500+ coding-agent trials across open-weight models, harnesses, configs, and local/cloud venues. Every score comes from executing the code the agent produced against a deterministic rubric.
>
> The harness matters as much as the model: on the same weights and tasks, changing the agent loop can move scores by dozens of points.
>
> Several cheap rented open-weight models cluster near the top, so the best practical choice is often not the highest-scoring model but the best score per dollar.
>
> Local GPU results mostly follow cloud rankings, but quantized local runs lose a few points, so the dashboard separates quality, VRAM fit, latency, and cost.

Bottom line: the work is strong. The current page makes the candidate look capable, but not as rigorous as the repo actually is. Lead with “reproducible coding-agent benchmark,” not “squeeze.”