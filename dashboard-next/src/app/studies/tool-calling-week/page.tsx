import type { Metadata } from "next";
import Link from "next/link";
import { studio } from "@/lib/site-data";
import { BUGS } from "@/lib/bugs";
import { cmp, finalState, fracPct, row, shortName, verdictStatus, verdictText } from "@/lib/studio-view";
import { Chip, DataTable, DotPlot, Figure, Keys, Legend, Note, StudyHead, fileHref, type DotRow } from "@/components/ui";

export const metadata: Metadata = {
  title: "Big local models as tool-calling agents",
  description: "A preregistered screen of open-weight models that fit in 128 GB of unified memory as tool-calling agents, scored on the end state of files, mail and messages.",
};

const abbrev = (n: string) =>
  n
    .replace("lean+x vs lean+ (code execution), 4 models pooled", "run_python vs none, 4 models pooled")
    .replace(": lean+x vs lean+ (code execution)", ": run_python vs none")
    .replace("Qwen3.8-Flash-Next", "Qwen3.8")
    .replace("Edge0-145B", "Edge0")
    .replace("Nemotron-3.5-Super", "Nemotron-Super")
    .replace(/Qwen3\.5-122B(-A10B)?/, "Qwen3.5")
    .replace(" heretic (abliterated)", " heretic")
    .replace(" (abliteration)", "")
    .replace(" (both reasoning high)", "")
    .replace(", 37 tasks", " · 37 tasks")
    .replace(", HARD", " · HARD")
    .replace(": lean+x vs pi harness, 30 tasks", ": lean+x vs pi");

const stops = (f: Record<string, number>) =>
  Object.entries(f)
    .map(([k, v]) => `${k.replace(/_/g, " ")} ${v}`)
    .join(", ") || "none";

export default function Page() {
  const s = studio();
  const ex = s.exploration;
  const week = ex.leanx_week;
  const fin = finalState();
  const edge = row("leanx_week", "edge0-145b")!;
  const q38 = row("leanx_week", "qwen3.8-flash-next")!;
  const pooled = cmp("lean+x vs lean+ (code execution), 4 models pooled");
  const abl = cmp("gpt-oss-120b: base vs heretic (abliteration), lean+x");
  const mlx = cmp("gpt-oss-120b: llama.cpp vs MLX");
  const eff = cmp("gpt-oss-120b: reasoning high vs medium");
  const q35 = cmp("Qwen3.8-Flash-Next vs Qwen3.5-122B");
  const h3 = cmp("Edge0-145B vs Qwen3.8-Flash-Next, HARD3");
  const piCmp = cmp("Qwen3.8-Flash-Next: lean+x vs pi harness");
  const mlxRow = row("leanx_week", "gpt-oss-120b-mlx")!;
  const effHigh = row("leanx_week", "gpt-oss-120b-effhigh")!;
  const base = row("leanx_week", "gpt-oss-120b-base")!;
  const nModels = new Set([...week, ...ex.smoke].map((r) => r.key.replace(/-(base|heretic|effhigh|mlx|rhigh|plain|abliterated)$/, "").replace(/-119b$/, ""))).size;
  const exoTasks = Object.values(ex).reduce((t, v) => t + v.reduce((a, r) => a + r.tasks, 0), 0);

  const screenRows: DotRow[] = week.map((r) => {
    const [lo, hi] = r.wilson95;
    return {
      label: (
        <>
          {shortName(r.model)}
          {r.model.includes("(") && <span className="s"> {r.model.match(/\((.*)\)/)?.[1]}</span>}
        </>
      ),
      title: `${r.model} · ${r.quant} · ${r.solved}/${r.tasks} solved · Wilson 95% ${Math.round(lo * 100)}–${Math.round(hi * 100)}% · fails: ${stops(r.fail_stops)}`,
      v: fracPct(r),
      lo: lo * 100,
      hi: hi * 100,
      val: `${r.solved}/${r.tasks}`,
      tone: r.solved === r.tasks ? "hi" : r.key.startsWith("mistral") ? "dim" : undefined,
    };
  });

  const hardRows: DotRow[] = [
    ...ex.leanx_hard2.map((r) => ({ r, g: "HARD2 · 15 harder tasks" })),
    ...ex.leanx_hard3.map((r) => ({ r, g: "HARD3 · 12 long-horizon tasks" })),
    ...ex.pi_week.map((r) => ({ r, g: "pi harness (bash, read, write, edit) · 30 tasks" })),
    ...ex.smoke.map((r) => ({ r, g: "5-task smoke checks" })),
  ].map(({ r, g }) => ({
    group: g,
    label: shortName(r.model),
    title: `${r.model} · ${r.quant} · ${r.solved}/${r.tasks}`,
    v: fracPct(r),
    lo: r.wilson95[0] * 100,
    hi: r.wilson95[1] * 100,
    val: `${r.solved}/${r.tasks}`,
    tone: r.solved === r.tasks ? ("hi" as const) : undefined,
  }));

  const execPairs = s.comparisons.filter((c) => c.name.includes("(code execution)") && !c.name.includes("pooled"));
  const execRows: DotRow[] = execPairs.map((c) => ({
    label: c.name.split(":")[0].replace(" heretic (abliterated)", " heretic"),
    title: `${c.name}: with run_python ${c.a}/${c.n}, without ${c.b}/${c.n}; difference ${c.diff} [${c.ci[0]}, ${c.ci[1]}]`,
    v: c.a,
    b: c.b,
    val: `${c.b} → ${c.a}`,
  }));

  const diffRows: DotRow[] = s.comparisons.map((c) => ({
    label: abbrev(c.name),
    title: `${c.name}: A ${c.a}, B ${c.b}, A−B ${c.diff} [${c.ci[0]}, ${c.ci[1]}] · ${c.verdict}${c.note ? " · " + c.note : ""}`,
    v: c.diff,
    lo: c.ci[0],
    hi: c.ci[1],
    val: `${c.diff > 0 ? "+" : ""}${c.diff}`,
    tone: c.verdict === "A ahead" ? "hi" : undefined,
  }));

  return (
    <>
      <StudyHead
        kicker="Benchmarks · tool calling · 128 GB workstation"
        title="Big local models as tool-calling agents"
        dek="Which open-weight model that fits in 128 GB of unified memory is the best tool-calling agent, when it is scored on what changed on disk, in the mailbox and in the message database?"
        chips={
          <>
            <Chip s="explore" />
            <Chip s="pending" />
          </>
        }
        meta={[
          ["Hardware", s.venue.hardware.replace(", GPU wired limit 120 GB", "")],
          ["Engine", "llama.cpp, one model at a time"],
          ["Models", `${nModels}, in ${week.length} configurations on the main screen`],
          ["Task rows so far", `${exoTasks} (exploration)`],
          ["Preregistered", "2026-11-18, before the first episode"],
          ["Final pass", `${fin.state}, ${fin.tasks} tasks per model`],
        ]}
        toc={[
          ["summary", "Summary"],
          ["question", "Question"],
          ["method", "Method"],
          ["results", "Results"],
          ["final", "Final pass"],
          ["bugs", "Harness bugs"],
          ["limits", "Limitations"],
          ["data", "Data"],
        ]}
      />

      <div className="col prose">
        <h2 id="summary">Summary</h2>
        <Note title="This is a screen of candidates. The ranking will come from the final pass." chip="explore">
          <p>
            Every number on this page is a single trial per task, run while the harness was still being fixed, so rows from
            different days are not on identical code. The frozen final pass (64 tasks, fresh seed) is the result, and it is still running.
          </p>
        </Note>
      </div>
      <div className="col-wide">
        <Keys
          items={[
            { v: `${edge.solved}/${edge.tasks}`, l: `${shortName(edge.model)} and ${shortName(q38.model)} on the 37 screening tasks`, s: "identical outcomes, task for task" },
            { v: `${mlx.a} vs ${mlx.b}`, l: "gpt-oss-120b on llama.cpp vs MLX (reasoning high)", s: `too wide to call, CI ${mlx.ci[0]} to +${mlx.ci[1]}, equal throughput` },
            { v: `${abl.a} = ${abl.b}`, l: "gpt-oss-120b vs its abliterated version", s: `too wide to call, CI ${abl.ci[0]} to +${abl.ci[1]}` },
            { v: `${piCmp.a} vs ${piCmp.b}`, l: `${shortName(q38.model)}: purpose-built toolset vs the pi harness, ${piCmp.n} tasks`, s: `too wide to call, CI ${piCmp.ci[0]} to +${piCmp.ci[1]}` },
          ]}
        />
      </div>

      <div className="col prose">
        <h2 id="question">Question</h2>
        <p>
          Of the open-weight models that fit a 128 GB unified-memory workstation (GPU memory limit raised to 120 GB), which does local tool
          calling best? The secondary question: does abliteration (removing a model&apos;s refusal direction) change how it uses tools?
        </p>
        <p>
          The question, the model list, the method and a written expectation were fixed before the first episode. Every change after that
          was logged as a dated amendment that states what had been seen at the time. Two of the expectations were wrong. The gpt-oss and
          Qwen3.5 models were expected in the top three, and neither is there.
        </p>

        <h2 id="method">Method</h2>
        <h3>Tasks</h3>
        <ul>
          <li>
            <strong>37 screening tasks</strong>: basic file work (8), stress (5), hard (9), general (5) and app tasks (10) against Gmail,
            iMessage and intranet look-alikes, some with planted prompt-injection traps.
          </li>
          <li>
            <strong>HARD2</strong>, 15 tasks written when the screen saturated: dirty data, buried policy exceptions, multi-app joins, stale
            caches, partial-failure recovery, injected instructions.
          </li>
          <li>
            <strong>HARD3</strong>, 12 tasks written when HARD2 saturated: data reachable only by per-item calls, 60 to 110-call ledgers,
            conflicting specs with a stated precedence, resuming without duplicate side effects, requests that must be refused, and two code
            tasks where the checker runs the agent&apos;s own regression test.
          </li>
        </ul>
        <h3>Scoring</h3>
        <p>
          Each task has several checks on the <em>end state</em>: files on disk, mailbox labels, drafts that were sent. What the model says
          it did is not scored. A task counts as solved only when every check passes. Every HARD2 and HARD3 task has a reference solution
          that passes and a check that an untouched workspace fails.
        </p>
        <h3>Agent and tools</h3>
        <ul>
          <li>
            <code>lean+</code>: 18 file, search and app tools (read, write, edit, bulk move and rename recipes, semantic search, mail and
            browser look-alikes, verify and rollback). No code execution.
          </li>
          <li>
            <code>lean+x</code>: lean+ plus <code>run_python</code>, 120 s per call in its own container with only the task workspace
            mounted, no network.
          </li>
          <li>
            <code>pi</code>: a general coding agent&apos;s four tools (bash, read, write, edit), run on the 30 tasks that need no app tools.
          </li>
        </ul>
        <h3>Serving</h3>
        <p>
          llama.cpp&apos;s server with its tool-call grammar, 131k context, full GPU offload, one model at a time, sampling per model card,
          at most 150 steps and a 16k-token reply cap. Reasoning is sent back between tool calls for models that think. Each model runs at
          the largest quantization that leaves room for 131k context (3 to 8 bits). That is the practical choice on this machine, and it
          means the models are not compared at a matched quantization.
        </p>
        <h3>Statistics</h3>
        <p>
          Solve rates carry a Wilson 95% interval. Differences between two runs are paired by task and get a bootstrap 95% interval over
          tasks. When that interval includes zero the gap is reported as <Chip s="wide" />. See <Link href="/methods/#stats">Methods</Link>.
        </p>

        <h2 id="results">Results</h2>
        <h3>The 37 screening tasks saturate at the top</h3>
        <p>
          With <code>run_python</code>{" "}available, {shortName(edge.model)} and {shortName(q38.model)} each solved all {edge.tasks} tasks and
          their outcomes are identical task for task. Five more configurations solved 33 or 34. The Mistral row ran with reasoning switched
          off by a configuration bug, and it is labelled as a reasoning-off run.
        </p>
      </div>
      <div className="col-wide">
        <Figure
          n="1"
          title="Tasks solved on the 37 screening tasks (lean+x)"
          sub="One trial per task. Bars are Wilson 95% intervals. Highlighted rows solved every task."
          caption={
            <>
              Source: <code>studio/summary.json</code>, <code>exploration.leanx_week</code>. These are exploration rows, and the harness changed
              between some of them (see Harness bugs).
            </>
          }
          table={
            <DataTable
              head={["model", "quant", "solved", "Wilson 95%", "checks", "fails by stop reason", "wall", "tok/s"]}
              right={[2, 3, 4, 6, 7]}
              rows={week.map((r) => [
                r.model,
                r.quant,
                `${r.solved}/${r.tasks}`,
                `${Math.round(r.wilson95[0] * 100)}–${Math.round(r.wilson95[1] * 100)}%`,
                `${r.checks_passed}/${r.checks_total}`,
                stops(r.fail_stops),
                `${Math.round(r.wall_min)} min`,
                r.decode_tok_s ? r.decode_tok_s.toFixed(1) : `${r.tok_s_over_wall?.toFixed(1)}*`,
              ])}
            />
          }
        >
          <DotPlot rows={screenRows} domain={[0, 100]} ticks={[0, 25, 50, 75, 100]} axis="tasks solved, % of 37" fmt={(x) => `${x}`} />
        </Figure>
      </div>

      <div className="col prose">
        <h3>The harder suites saturate too, at the very top</h3>
        <p>
          Both leaders solved all 15 HARD2 tasks. They read the spec, dump the data with one <code>run_python</code>{" "}call and script the
          rest. On HARD3 the split was {h3.a} vs {h3.b}. That comparison is not clean, since the three tasks the second model missed are the
          three whose checkers were found broken and fixed before the first model ran. The final pass reruns both on the fixed checkers.
        </p>
      </div>
      <div className="col-wide">
        <Figure
          n="2"
          title="Harder suites, the pi harness and smoke checks"
          sub="One trial per task, Wilson 95% intervals. Small task counts make every interval wide."
          caption={<>Source: <code>studio/summary.json</code>, <code>exploration.leanx_hard2</code>, <code>leanx_hard3</code>, <code>pi_week</code>, <code>smoke</code>.</>}
        >
          <DotPlot rows={hardRows} domain={[0, 100]} ticks={[0, 25, 50, 75, 100]} axis="tasks solved, %" />
        </Figure>
      </div>

      <div className="col prose">
        <h3 id="exec">Why the screen runs with code execution</h3>
        <p>
          The screen started on a toolset with no code execution and switched after four models had run. It is well known that an agent
          does better when it can run code, and this is reported here as the reason for the switch. Pooled over the four models, solved
          tasks went from {pooled.b} to {pooled.a} over {pooled.n} shared tasks, a difference of +{pooled.diff} with a 95% interval of +
          {pooled.ci[0]} to +{pooled.ci[1]}. Without execution, a model writes a script it cannot run and then tries to do the computation in
          its reasoning until it reaches the reply cap. Each model on its own gains {Math.min(...execPairs.map((c) => c.diff))} to{" "}
          {Math.max(...execPairs.map((c) => c.diff))} tasks, and each of those intervals is too wide to call. The rows without execution are
          kept as a paired baseline and that toolset is not run again.
        </p>
      </div>
      <div className="col-wide">
        <Figure
          n="3"
          title="Tasks solved without and with run_python, same 35 tasks"
          sub="Grey dot: lean+ (no code execution). Blue dot: lean+x. Two tasks that need execution are left out."
          caption={<>Source: <code>studio/summary.json</code>, <code>comparisons</code>. Per-model intervals are in Figure 4.</>}
        >
          <Legend
            items={[
              { c: "var(--mark-muted)", l: "without run_python" },
              { c: "var(--mark)", l: "with run_python" },
            ]}
          />
          <DotPlot rows={execRows} domain={[15, 35]} ticks={[15, 20, 25, 30, 35]} axis="tasks solved of 35" />
        </Figure>

        <Figure
          n="4"
          title="Every paired comparison in the screen"
          sub="Difference in tasks solved (A minus B) with a bootstrap 95% interval over tasks. The highlighted rows have an interval that clears zero."
          caption={<>Source: <code>studio/summary.json</code>, <code>comparisons</code>. Notes on each comparison are in the table.</>}
          table={
            <DataTable
              head={["A vs B", "tasks", "A", "B", "A−B", "95% CI", "verdict", "note"]}
              right={[1, 2, 3, 4, 5]}
              rows={s.comparisons.map((c) => [c.name, c.n, c.a, c.b, c.diff, `${c.ci[0]} to ${c.ci[1]}`, <Chip key="v" s={verdictStatus(c.verdict)}>{verdictText(c.verdict)}</Chip>, c.note])}
            />
          }
        >
          <DotPlot rows={diffRows} domain={[-6, 34]} ticks={[-5, 0, 5, 10, 15, 20, 25, 30]} axis="difference in tasks solved (A − B)" zero />
        </Figure>
      </div>

      <div className="col prose">
        <h3 id="smaller">Engine, abliteration, reasoning effort and the pi harness</h3>
        <ul>
          <li>
            <strong>Engine.</strong>{" "}On gpt-oss-120b at high reasoning, llama.cpp solved {mlx.a}/{mlx.n} and MLX solved {mlx.b}/{mlx.n},
            which is too wide to call (95% CI {mlx.ci[0]} to +{mlx.ci[1]}). Throughput over wall time was {effHigh.tok_s_over_wall?.toFixed(0)}{" "}
            against {mlxRow.tok_s_over_wall?.toFixed(0)} tok/s. {mlxRow.fail_stops.empty_reply ?? 0} of the {mlxRow.tasks - mlxRow.solved} tasks
            MLX failed ended in an empty reply, which is a tool call its parser could not read. llama.cpp&apos;s grammar constrains the call, so
            it had {effHigh.fail_stops.empty_reply ?? 0}. MLX ran this model with tools only after its parser was patched.
          </li>
          <li>
            <strong>Abliteration.</strong>{" "}gpt-oss-120b and its abliterated version solved the same number of tasks with execution (
            {abl.a} and {abl.b}) and without it ({cmp("gpt-oss-120b: base vs heretic (abliteration), lean+").a} and{" "}
            {cmp("gpt-oss-120b: base vs heretic (abliteration), lean+").b}). The interval on the difference is {abl.ci[0]} to +{abl.ci[1]} tasks,
            so a small cost is not ruled out. Without execution the abliterated model obeyed a prompt injection planted in an order-status
            page, and the base model did not. This is one trial on one trap, and it is a lead for a follow-up study.
          </li>
          <li>
            <strong>The pi harness.</strong>{" "}pi gives the model four tools (bash, read, write, edit) and has no mail or browser tools, so
            it ran the {piCmp.n} tasks that need none. {shortName(q38.model)} solved {piCmp.b} of them through pi and {piCmp.a} through the
            purpose-built toolset, which is too wide to call (95% CI {piCmp.ci[0]} to +{piCmp.ci[1]}).
          </li>
          <li>
            <strong>Reasoning effort.</strong>{" "}High against medium on gpt-oss-120b gave {eff.a} vs {eff.b}, too wide to call, at about{" "}
            {Math.round(effHigh.wall_min / base.wall_min)}× the wall time ({Math.round(effHigh.wall_min)} vs {Math.round(base.wall_min)} min).
          </li>
          <li>
            <strong>Generations.</strong>{" "}Qwen3.8-Flash-Next solved {q35.diff} more tasks than its predecessor Qwen3.5-122B (95% CI +{q35.ci[0]}{" "}
            to +{q35.ci[1]}), the only single-model gap in the screen whose interval clears zero.
          </li>
          <li>
            <strong>Speed.</strong> {shortName(edge.model)} decoded at {edge.decode_tok_s?.toFixed(0)} tok/s on its own engine and finished
            the 37 tasks in {Math.round(edge.wall_min)} min, against {Math.round(q38.wall_min)} min for {shortName(q38.model)} on llama.cpp. Its
            weights are a rebuild of that model, so the difference comes from the engine as well as the model.
          </li>
          <li>
            <strong>Failure modes.</strong>{" "}After the harness bugs were fixed, the remaining failures were on the model side. They were
            claims of being done with the work undone, a swapped pair of letters when writing an answer, missed receipts that do not contain
            the word receipt, and reasoning loops that run to the reply cap.
          </li>
        </ul>

        <h2 id="final">Final pass</h2>
        <p>
          The top six models from the screen plus one dense 65B model run all {fin.tasks} tasks (37 + HARD2 + HARD3) on <code>lean+x</code>,
          once each, on a harness that was hashed before the start, with fresh workspaces at a seed offset ({fin.seed_offset}) never used in
          exploration. Pairwise differences use the same bootstrap and the same &ldquo;too wide to call&rdquo; rule.
        </p>
        <Note title={`State: ${fin.state}`} chip="pending">
          {fin.done.length === 0 ? (
            <p>No model has finished its pass, so there is no final score yet. Partial rows show progress only.</p>
          ) : (
            <p>{fin.done.length} model(s) have finished. Scores count only once a model&apos;s pass is complete.</p>
          )}
          <ul>
            {fin.partial.map((m) => (
              <li key={m.tag}>
                {m.model}: {m.tasks} of {m.expected_tasks} tasks run
              </li>
            ))}
            {fin.done.map((m) => (
              <li key={m.tag}>
                {m.model}: {m.solved}/{m.tasks} solved
              </li>
            ))}
          </ul>
          <p>With one pass per model, a gap of one to three tasks between the top two is expected to be too wide to call.</p>
        </Note>

        <h2 id="bugs">Harness bugs</h2>
        <p>
          The exploration found {BUGS.length} harness bugs. Most of them made a model look worse than it was, and{" "}
          {BUGS.filter((x) => /better/.test(x.e)).length} made or could have made one look better. First, llama.cpp&apos;s grammar forces tool-call keys into schema order, so one model could not add an optional key
          once it had passed it. Second, the mail mock ignored parenthesised queries and returned nothing. Third, the code-execution jail
          could read the expected answers. Last, the simulated world&apos;s date disagreed with the host clock. Rows run before a fix are kept
          as found and are not rerun. The full log is on the <Link href="/methods/#bugs">Methods</Link>{" "}page.
        </p>

        <h2 id="limits">Limitations</h2>
        <ul>
          <li>One trial per task everywhere. A Wilson interval on 37 tasks is roughly ±10 points, and most pairwise gaps are inside it.</li>
          <li>The harness changed during exploration. Rows were run before, between and after the fixes, and rows from before a fix understate the models it hit (gpt-oss most of all).</li>
          <li>The quantization is not matched across models (3 to 8 bits), and the fastest model ran on a different engine.</li>
          <li>The tasks, tools and checkers are ours, and the harness is not public yet. Task names, check names and every per-task row are.</li>
          <li>The largest model (235B at 3 bits) ran at 65k context because 131k did not fit, so its rows are not on the same context.</li>
          <li>The world-clock bug could affect date-relative tasks in any exploration row. The final pass is the first run with the date pinned.</li>
        </ul>

        <h2 id="data">Data</h2>
        <ul>
          <li>
            <a href={fileHref("data/studio-summary.json")}>studio-summary.json</a>: every table and comparison on this page.
          </li>
          <li>
            <a href={fileHref("data/studio-rows.jsonl")}>studio-rows.jsonl</a>: one row per task (model, task, suite, checks, solved, steps,
            tool calls, tokens, timings, stop reason, failed check names).
          </li>
        </ul>
        <pre>
          <code>{`bin/studio-summary   # rebuild studio/summary.json from studio/rows/`}</code>
        </pre>
      </div>
    </>
  );
}
