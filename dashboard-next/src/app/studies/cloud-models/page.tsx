import type { Metadata } from "next";
import Link from "next/link";
import { cloud, fmtCost, fmtCI } from "@/lib/site-data";
import Scatter, { type Pt } from "@/components/Scatter";
import { Chip, DataTable, DotPlot, Figure, Keys, Legend, Note, StudyHead, fileHref, type DotRow } from "@/components/ui";

export const metadata: Metadata = {
  title: "Open models as coding agents, compared",
  description: "Single open-weight models and multi-model mixes on one coding suite, with cluster-bootstrap intervals and cost per task.",
};

export default function Page() {
  const c = cloud();
  const tiedKeys = new Set(c.tied.map((a) => a.key));
  const top = c.arms[0];
  const v = c.value!;
  const label = (a: { model: string; kind: string }) => a.model;

  const boardRows: DotRow[] = c.arms.map((a) => ({
    group: undefined,
    label: (
      <>
        {label(a)}
        {a.kind === "mix" && <span className="s"> · mix</span>}
      </>
    ),
    title: `${a.model} (${a.harness}) · ${a.evals} evals, ${a.n} runs · mean ${a.mean}% · 95% CI ${fmtCI(a.lo, a.hi, 1)} · ${fmtCost(a.costPerTask)}/task`,
    v: a.mean,
    lo: a.lo,
    hi: a.hi,
    val: a.mean.toFixed(1),
    hollow: a.kind === "mix",
    tone: tiedKeys.has(a.key) ? "hi" : undefined,
  }));

  const LABELED = ["llama-3.1-8b", "mistral-small-3.2", "deepseek-r1", "qwen3-coder-30b", "deepseek-v4-flash"];
  const labelSet = new Set([top.key, v.key, ...c.arms.filter((a) => a.kind === "single" && LABELED.includes(a.model)).map((a) => a.key)]);
  const pts: Pt[] = c.arms
    .filter((a) => a.costPerTask)
    .map((a) => ({
      x: a.costPerTask!,
      y: a.mean,
      label: a.model,
      mix: a.kind === "mix",
      hi: a.key === v.key || a.key === top.key,
      showLabel: labelSet.has(a.key),
      title: `${a.model} · ${a.mean}% · ${fmtCost(a.costPerTask)}/task`,
    }));

  const CLOSED = new Set(["claude-opus-4.8", "gpt-5.5"]);
  const hardRows: DotRow[] = c.hard.arms.map((a) => ({
    label: (
      <>
        {a.model}
        {CLOSED.has(a.model) && <span className="s"> · closed</span>}
      </>
    ),
    hollow: CLOSED.has(a.model),
    title: `${a.model} · ${a.evals} hard evals, ${a.n} runs · ${a.mean}% · CI ${fmtCI(a.lo, a.hi, 1)}`,
    v: a.mean,
    lo: a.lo,
    hi: a.hi,
    val: a.mean.toFixed(1),
  }));

  const r1 = c.arms.find((a) => a.model === "deepseek-r1");
  const coders = c.arms.filter((a) => /codestral|devstral/.test(a.model));

  return (
    <>
      <StudyHead
        kicker="Study · coding agents · cloud-served open weights"
        title="Open models as coding agents, compared"
        dek={`${c.nSingles} open-weight models and ${c.nMixes} multi-model mixes on one coding suite, scored by running their code. Where does the top really sit, and what does it cost?`}
        chips={<Chip s="wide">Top cluster: too close to call</Chip>}
        meta={[
          ["Runs", `${c.nRuns.toLocaleString("en-US")}`],
          ["Evals", `${c.nEvals} (one environment-dependent eval excluded)`],
          ["Arms", `${c.nSingles} single models, ${c.nMixes} mixes`],
          ["Trials", `${(c.nRuns / c.arms.length / c.nEvals).toFixed(1)} per eval per arm (mean)`],
          ["API spend", `$${c.totalCost.toFixed(2)}`],
          ["Dates", `${c.dates[0]} to ${c.dates[1]}`],
        ]}
        toc={[
          ["summary", "Summary"],
          ["method", "Method"],
          ["board", "Leaderboard"],
          ["cost", "Cost"],
          ["hard", "Hard tier"],
          ["limits", "Limitations"],
          ["data", "Data"],
        ]}
      />
      <div className="col-wide">
        <Keys
          items={[
            { v: `${c.tied.length}`, l: `arms whose interval reaches the top arm's lower bound (${top.lo}%)`, s: "a cluster, not a winner" },
            { v: fmtCost(v.costPerTask), l: `per task for ${v.model} at ${v.mean.toFixed(1)}%`, s: `${v.scorePerDollar?.toLocaleString("en-US")} score points per dollar` },
            { v: `${c.bestMix.mean.toFixed(1)} vs ${c.bestSingle.mean.toFixed(1)}`, l: `best mix (${c.bestMix.model}) vs best single model`, s: "mixes do not raise the ceiling" },
          ]}
        />
      </div>
      <div className="col prose">
        <h2 id="summary">Summary</h2>
        <ul>
          <li>
            <strong>The top is a tie.</strong> {c.tied.length} arms, single models and mixes, have intervals that reach the leader&apos;s lower
            bound. Ranking inside that group is not supported by the data.
          </li>
          <li>
            <strong>Value:</strong> {v.model} scores {v.mean.toFixed(1)}% (95% CI {fmtCI(v.lo, v.hi)}) for about {fmtCost(v.costPerTask)} a task,
            a few points below the cluster at a small fraction of its cost.
          </li>
          <li>
            <strong>Mixes</strong> (a frontier model planning for a cheap one, draft-critique-refine, ensembles, write-tests-then-fix) sit
            inside or below the cluster; none scores above the best single model. Their use is rescuing weak models.
          </li>
          <li>
            <strong>Reasoning and coding-specialist models</strong> did not stand out: {r1 && <>deepseek-r1 scored {r1.mean.toFixed(1)}%</>}
            {coders.length > 0 && <>, and {coders.map((a) => `${a.model} ${a.mean.toFixed(1)}%`).join(", ")}</>}.
          </li>
        </ul>

        <h2 id="method">Method</h2>
        <ul>
          <li>
            Every arm runs under the same reference agent loop (squeezer) or a mix built on it, against the same prompts and rubrics, through
            one API provider. Only the model changes. Under a stronger harness, weaker models would score higher (see the{" "}
            <Link href="/studies/harness-bakeoff/">harness bake-off</Link>).
          </li>
          <li>
            Score: the mean over evals of each eval&apos;s mean over its trials, so every eval weighs the same; a failed run counts as zero.
            Interval: cluster bootstrap over evals (2,000 resamples, seeded). Arms are ordered by lower bound, as in <code>bin/cloud-report</code>.
          </li>
          <li>
            One eval (a port scanner) needs live sockets that did not behave on the scoring machine, so every arm scored about 20% on it. It
            measured the environment, not the model, and is excluded ({c.nExcluded} runs).
          </li>
        </ul>

        <h2 id="board">Leaderboard</h2>
      </div>
      <div className="col-wide">
        <Figure
          n="1"
          title="Mean score by arm, with 95% intervals"
          sub="Highlighted: arms whose interval reaches the top arm's lower bound. Hollow: multi-model mixes."
          caption={<>Source: <code>runs.jsonl</code>, <code>host</code> = openrouter, <code>tag</code> = fable-hunt.</>}
          table={
            <DataTable
              head={["arm", "kind", "evals", "runs", "mean %", "95% CI", "$/task", "score per $", "mean wall"]}
              right={[2, 3, 4, 5, 6, 7, 8]}
              hi={c.arms.map((a, i) => (tiedKeys.has(a.key) ? i : -1)).filter((i) => i >= 0)}
              rows={c.arms.map((a) => [a.model, a.kind === "mix" ? `mix (${a.pipeline})` : "single", a.evals, a.n, a.mean.toFixed(1), fmtCI(a.lo, a.hi, 1), fmtCost(a.costPerTask), a.scorePerDollar?.toLocaleString("en-US") ?? "n/r", `${a.wallMean}s`])}
            />
          }
        >
          <Legend
            items={[
              { c: "var(--mark-hi)", l: "tied with the top" },
              { c: "var(--mark)", l: "single model" },
              { c: "var(--mark)", l: "mix", kind: "ring" },
              { c: "", l: "95% interval", kind: "bar" },
            ]}
          />
          <DotPlot rows={boardRows} domain={[0, 100]} ticks={[0, 25, 50, 75, 100]} axis="mean score %" />
        </Figure>
      </div>

      <div className="col prose">
        <h2 id="cost">What the score costs</h2>
        <p>
          Cost per task spans more than two orders of magnitude while the top of the score range is flat. The dashed line is the frontier:
          the best score available at or below each price.
        </p>
      </div>
      <div className="col-wide">
        <Figure
          n="2"
          title="Mean score against mean cost per task"
          sub="Filled: single model. Hollow: mix. Lemon: the top arm and the value pick. Hover a point for its name."
          caption="Cost is the provider-reported cost of the run's API calls, averaged over all runs of the arm. Scoring compute is not included."
        >
          <Scatter pts={pts} xTicks={[0.0001, 0.001, 0.01, 0.1]} yDomain={[10, 100]} />
        </Figure>
      </div>

      <div className="col prose">
        <h2 id="hard">Hard tier</h2>
        <p>
          The main suite saturates, so a separate tier of {c.hard.nEvals} harder tasks ({c.hard.evals.join(", ")}) was run on a subset of models,
          including two closed frontier models for reference. With {c.hard.nEvals} evals and few trials, intervals are wide.
        </p>
      </div>
      <div className="col-wide">
        <Figure
          n="3"
          title="Hard tier: mean score by model"
          sub={`${c.hard.nRuns} runs, ${c.hard.dates[0]} to ${c.hard.dates[1]}. Cluster-bootstrap 95% intervals over ${c.hard.nEvals} evals.`}
          caption={<>Source: <code>runs.jsonl</code>, tag <code>hard-tier</code>. Not comparable with Figure 1: different tasks.</>}
          table={
            <DataTable
              head={["model", "evals", "runs", "mean %", "95% CI", "$/task"]}
              right={[1, 2, 3, 4, 5]}
              rows={c.hard.arms.map((a) => [a.model, a.evals, a.n, a.mean.toFixed(1), fmtCI(a.lo, a.hi, 1), fmtCost(a.costPerTask)])}
            />
          }
        >
          <DotPlot rows={hardRows} domain={[0, 100]} ticks={[0, 25, 50, 75, 100]} axis="mean score %" />
        </Figure>
      </div>

      <div className="col prose">
        <Note title="An earlier write-up used older numbers" chip="hist">
          <p>
            The repository&apos;s FINDINGS-CLOUD.md was written from an earlier state of the same sweep (39 evals). This page is computed from
            the current <code>runs.jsonl</code>, so some values differ (for example the value pick&apos;s mean). Where they disagree, this page
            is the data.
          </p>
        </Note>
        <h2 id="limits">Limitations</h2>
        <ul>
          <li>Home-field suite: our tasks, leaning algorithmic, and saturated at the top. A standard external benchmark is still queued.</li>
          <li>Sampling used each provider&apos;s defaults; about two trials per cell.</li>
          <li>Providers serve higher precision than a local 4-bit build, so these are upper bounds for running the same model at home (see the <Link href="/studies/local-4070/">local study</Link>).</li>
          <li>No sandbox for the agent shell in this suite (a rubric could be read mid-run; not observed).</li>
        </ul>
        <h2 id="data">Data</h2>
        <p>
          <a href={fileHref("data/runs.jsonl")}>runs.jsonl</a>: filter <code>host</code> = <code>openrouter</code> and <code>tag</code> ={" "}
          <code>fable-hunt</code> (or <code>hard-tier</code>).
        </p>
        <pre>
          <code>{`bin/cloud-report --tag fable-hunt --by-eval
bin/cloud-report --tag hard-tier`}</code>
        </pre>
      </div>
    </>
  );
}
