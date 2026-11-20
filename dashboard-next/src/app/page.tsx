import Link from "next/link";
import type { ReactNode } from "react";
import { bakeoff, cloud, fmtCost, fmtCI, local } from "@/lib/site-data";
import { cmp, finalState, row, shortName } from "@/lib/studio-view";
import { Chip, DotPlot, Legend, type DotRow, type Status } from "@/components/ui";
import StudyCards from "@/components/StudyCards";

type F = { claim: string; status: Status[]; body: ReactNode; uncertainty: ReactNode; href: string; study: string; fig?: ReactNode };

export default function Home() {
  const b = bakeoff();
  const c = cloud();
  const L = local();
  const fin = finalState();
  const pooled = cmp("lean+x vs lean+ (code execution), 4 models pooled");
  const abl = cmp("gpt-oss-120b: base vs heretic (abliteration), lean+x");
  const edge = row("leanx_week", "edge0-145b")!;
  const q38 = row("leanx_week", "qwen3.8-flash-next")!;
  const h2e = row("leanx_hard2", "edge0-145b")!;
  const moe = L.models.find((m) => m.model === "gpt-oss:20b")!;
  const dense = L.models.find((m) => m.model === "qwen3:14b")!;
  const weak = b.perModel.filter((m) => m.diff > 30);
  const qc = b.perModel.find((m) => m.label === "qwen3-coder-30b");
  const cheapTied = c.tied.filter((a) => a.kind === "single" && a.costPerTask).sort((x, y) => x.costPerTask! - y.costPerTask!)[0];

  const harnessFig: DotRow[] = b.perModel.map((m) => ({
    label: m.label,
    title: `${m.label}: squeezer ${m.bMean}% → aider ${m.aMean}% (${m.cells} shared cells)`,
    v: m.aMean,
    b: m.bMean,
    val: `${m.bMean.toFixed(0)} → ${m.aMean.toFixed(0)}`,
  }));

  const findings: F[] = [
    {
      claim: "On weak models, the agent harness matters more than the model.",
      status: ["solid"],
      body: (
        <p>
          Holding the weights and tasks fixed and changing only the harness, aider&apos;s edit format beat our minimal tool-calling loop by{" "}
          {b.paired.diff.toFixed(1)} points over {b.paired.cells} paired cells (95% CI +{b.paired.lo} to +{b.paired.hi}).{" "}
          {weak.map((m, i) => (
            <span key={m.label}>
              {i ? " and " : ""}
              {m.label} went from {m.bMean.toFixed(0)}% to {m.aMean.toFixed(0)}%
            </span>
          ))}
          . Strong models scored 100 under both.
        </p>
      ),
      uncertainty: (
        <>
          The direction is solid; the size per model is not. {qc?.label} rests on {qc?.cells} cells and the strong-model tie on two each.
        </>
      ),
      href: "/studies/harness-bakeoff/",
      study: "Harness bake-off",
      fig: (
        <>
          <Legend
            items={[
              { c: "var(--mark-muted)", l: "minimal loop" },
              { c: "var(--mark)", l: "aider" },
            ]}
          />
          <DotPlot rows={harnessFig} domain={[0, 100]} ticks={[0, 50, 100]} axis="mean score % on shared cells" />
        </>
      ),
    },
    {
      claim: "Letting a local agent run code is the biggest single lever we have measured for tool calling.",
      status: ["explore"],
      body: (
        <p>
          Four big local models ran the same {pooled.n} tasks with and without a sandboxed <code>run_python</code> tool. Pooled, solved tasks
          went from {pooled.b} to {pooled.a}: +{pooled.diff} (95% CI +{pooled.ci[0]} to +{pooled.ci[1]}). Without it, models write a script they
          cannot run and then try to compute the answer in their reasoning until they run out of tokens.
        </p>
      ),
      uncertainty: <>One trial per task on a harness that was still being fixed. Each model&apos;s own gain (+3 to +5) is too wide to call.</>,
      href: "/studies/tool-calling-week/",
      study: "Tool-calling screen",
    },
    {
      claim: "The best open models that fit in 128 GB now saturate our tool-calling tasks.",
      status: ["explore", "pending"],
      body: (
        <p>
          {shortName(edge.model)} and {shortName(q38.model)} each solved {edge.solved}/{edge.tasks} screening tasks with identical outcomes, and{" "}
          {h2e.solved}/{h2e.tasks} on a harder set written after the first one saturated. Five more configurations solved 33 or 34 of 37.
        </p>
      ),
      uncertainty: (
        <>
          A screen, not a ranking. The frozen final pass ({fin.tasks} tasks per model) is {fin.state}; no model has a final score yet. On the
          hardest set the comparison between the top two is not clean because checkers were fixed between their runs.
        </>
      ),
      href: "/studies/tool-calling-week/",
      study: "Tool-calling screen",
    },
    {
      claim: "Among cloud-served open models, the top of our coding board is a tie, and near-top quality costs well under a cent a task.",
      status: ["wide"],
      body: (
        <p>
          {c.tied.length} arms have intervals that reach the leader&apos;s lower bound ({c.arms[0].model}, {c.arms[0].mean}%). {c.value?.model}{" "}
          scores {c.value?.mean.toFixed(1)}% (CI {fmtCI(c.value!.lo, c.value!.hi)}) for {fmtCost(c.value?.costPerTask)} a task.
        </p>
      ),
      uncertainty: <>Our own suite, which saturates at the top; about two trials per cell; provider-default sampling.</>,
      href: "/studies/cloud-models/",
      study: "Cloud model comparison",
    },
    {
      claim: "Multi-model mixes rescue weak models but do not raise the ceiling.",
      status: ["wide"],
      body: (
        <p>
          The best mix ({c.bestMix.model}, {c.bestMix.mean.toFixed(1)}%) sits inside the top cluster, below the best single model (
          {c.bestSingle.model}, {c.bestSingle.mean.toFixed(1)}%). It costs {fmtCost(c.bestMix.costPerTask)} a task, against{" "}
          {fmtCost(cheapTied?.costPerTask)} for {cheapTied?.model}, the cheapest single model in the same cluster.
        </p>
      ),
      uncertainty: <>Differences at the top are inside the intervals; &ldquo;no better&rdquo; is the claim, not &ldquo;worse&rdquo;.</>,
      href: "/studies/cloud-models/",
      study: "Cloud model comparison",
    },
    {
      claim: "On a 12 GB card, a mixture-of-experts model scored best and drew about a quarter of the power of a dense one.",
      status: ["explore"],
      body: (
        <p>
          Through aider, {moe.model} averaged {moe.mean.toFixed(1)}% over {moe.evals} evals at {moe.powerW} W mean GPU power ({moe.whPerTask} Wh a
          task). The dense {dense.model} averaged {dense.mean.toFixed(1)}% at {dense.powerW} W ({dense.whPerTask} Wh).
        </p>
      ),
      uncertainty: <>The models were not run on identical eval sets, and most cells have one trial. Power is GPU board power only.</>,
      href: "/studies/local-4070/",
      study: "12 GB GPU study",
    },
    {
      claim: "Running a model as a 4-bit local build showed no detectable score loss against the same model in the cloud.",
      status: ["wide"],
      body: (
        <p>
          Paired on the evals both venues ran, local minus cloud was{" "}
          {L.venue.map((p) => `${p.diff > 0 ? "+" : ""}${p.diff.toFixed(1)} points for ${p.label} (CI ${p.lo} to ${p.hi})`).join(" and ")}. This
          corrects an earlier write-up that reported a 3 to 5 point loss.
        </p>
      ),
      uncertainty: <>The intervals are about ±20 points. A small loss is not ruled out; it is just not visible at this sample size.</>,
      href: "/studies/local-4070/#venue",
      study: "12 GB GPU study",
    },
    {
      claim: "Abliteration did not change how gpt-oss-120b uses tools.",
      status: ["explore", "wide"],
      body: (
        <p>
          The base model and its abliterated version solved the same number of tasks ({abl.a} = {abl.b} with code execution, and equal without
          it). In one task the abliterated model followed a prompt injection planted in a web page; the base model did not.
        </p>
      ),
      uncertainty: <>Single trials; the 95% interval on the difference is {abl.ci[0]} to +{abl.ci[1]} tasks. The injection result is one trap, one trial.</>,
      href: "/studies/tool-calling-week/",
      study: "Tool-calling screen",
    },
    {
      claim: "Agent benchmarks need a bug hunt before they need more models.",
      status: [],
      body: (
        <p>
          Roughly half of the first day&apos;s failures in the tool-calling screen were the harness: a decoding grammar that fixes key order, a
          mail mock that ignored parentheses, a code jail that could read the answers, a simulated clock three weeks off the host&apos;s. In the
          coding suite, 26 rubrics could award full marks to a stub until an audit rewrote them.
        </p>
      ),
      uncertainty: <>A methods observation from two benchmarks, documented bug by bug.</>,
      href: "/methods/#bugs",
      study: "Methods",
    },
  ];

  return (
    <>
      <section className="masthead col-wide">
        <div className="kicker">An independent local-LLM lab</div>
        <h1>What open-weight models finish when they work as agents</h1>
        <p className="dek col" style={{ marginLeft: 0 }}>
          We run open-weight language models as agents on hardware a person can own (a 12 GB gaming GPU, a 128 GB workstation) and on rented
          endpoints, and score each run by executing its code or inspecting the state it left behind. Below is what we currently believe, the
          evidence for it, and how sure we are.
        </p>
        <div className="chips" style={{ marginTop: "1rem" }}>
          <span className="ui small muted" style={{ marginRight: "0.3rem" }}>
            Labels:
          </span>
          <Chip s="solid" />
          <Chip s="wide" />
          <Chip s="explore" />
          <Chip s="pending" />
          <Link href="/methods/#labels" className="ui small" style={{ marginLeft: "0.4rem" }}>
            what they mean
          </Link>
        </div>
      </section>

      <section className="col-wide" aria-label="Findings" style={{ marginTop: "2rem" }}>
        <h2 className="kicker" style={{ margin: "0 0 0.4rem", fontSize: "0.78rem" }}>
          Findings
        </h2>
        {findings.map((f, i) => (
          <article className="finding" key={i}>
            <div className="n">{String(i + 1).padStart(2, "0")}</div>
            <div className="body">
              <div style={{ display: "grid", gap: "0 2rem", gridTemplateColumns: f.fig ? "minmax(0, 1fr)" : undefined }}>
                <div className="col" style={{ marginLeft: 0 }}>
                  <h3>{f.claim}</h3>
                  {f.body}
                  <p className="uncert">
                    <b>Uncertainty</b>
                    {f.uncertainty}
                  </p>
                </div>
                {f.fig && <div style={{ maxWidth: "44rem", marginTop: "0.6rem" }}>{f.fig}</div>}
              </div>
              <div className="ev">
                {f.status.map((s) => (
                  <Chip key={s} s={s} />
                ))}
                <Link href={f.href}>Evidence: {f.study} →</Link>
              </div>
            </div>
          </article>
        ))}
      </section>

      <section className="col-wide" style={{ marginTop: "3rem" }}>
        <h2 id="studies">Studies</h2>
        <StudyCards />
        <p className="ui small muted">
          Next: the tool-calling final pass, the coding suite on the 128 GB workstation so big local models land on the same ruler as the cloud,
          and a standard external benchmark.
        </p>
      </section>
    </>
  );
}
