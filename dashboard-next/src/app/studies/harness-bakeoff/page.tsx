import type { Metadata } from "next";
import Link from "next/link";
import { bakeoff, fmtCost, fmtCI } from "@/lib/site-data";
import { Chip, DataTable, DotPlot, Figure, Keys, Legend, Note, StudyHead, fileHref, type DotRow } from "@/components/ui";

export const metadata: Metadata = {
  title: "Coding-agent harness bake-off",
  description: "Same model, same tasks, different agent harness: how much of a coding agent's score is the harness?",
};

const HARNESS_NAME: Record<string, string> = {
  "aider-cloud": "aider",
  "claude-code-cloud": "Claude Code",
  "cline-cloud": "Cline",
  "codex-cloud": "Codex CLI",
  "crush-cloud": "Crush",
  "opencode-cloud": "opencode",
  "pi-cloud": "pi",
  "squeezer-cloud": "squeezer (reference)",
};

export default function Page() {
  const b = bakeoff();
  const p = b.paired;
  const weak = b.perModel.filter((m) => m.diff > 30);
  const strong = b.perModel.filter((m) => m.aMean === 100 && m.bMean === 100);

  const pairRows: DotRow[] = b.perModel.map((m) => ({
    label: (
      <>
        {m.label} <span className="s">· {m.cells} cells</span>
      </>
    ),
    title: `${m.label}: aider ${m.aMean}%, squeezer ${m.bMean}% over ${m.cells} shared cells`,
    v: m.aMean,
    b: m.bMean,
    val: `${m.bMean.toFixed(0)} → ${m.aMean.toFixed(0)}`,
  }));

  const deltaRows: DotRow[] = [p, ...b.perModel].map((m, i) => ({
    label: i === 0 ? <strong>all models</strong> : m.label,
    title: `${m.label}: aider − squeezer = ${m.diff} points, 95% CI ${m.lo} to ${m.hi}, ${m.cells} cells`,
    v: m.diff,
    lo: m.lo,
    hi: m.hi,
    val: `${m.diff > 0 ? "+" : ""}${m.diff.toFixed(0)}`,
    tone: i === 0 ? "hi" : undefined,
  }));

  const hs = [...b.harnesses];
  if (b.squeezerRef) hs.push(b.squeezerRef);
  hs.sort((x, y) => y.mean - x.mean);
  const harnessRows: DotRow[] = hs.map((a) => {
    const vendor = a.model !== "deepseek-v4-pro";
    return {
      label: (
        <>
          {HARNESS_NAME[a.harness] ?? a.harness}
          {vendor && <span className="s"> · own model</span>}
        </>
      ),
      title: `${a.harness} · model ${a.model} · ${a.evals} evals · mean ${a.mean}% · 95% CI ${fmtCI(a.lo, a.hi, 1)}`,
      v: a.mean,
      lo: a.lo,
      hi: a.hi,
      val: a.mean.toFixed(1),
      hollow: vendor,
      tone: a.harness === "squeezer-cloud" ? "dim" : undefined,
    };
  });

  return (
    <>
      <StudyHead
        kicker="Study · coding agents · cloud-served open weights"
        title="Coding-agent harness bake-off"
        dek="Hold the model and the tasks fixed and change only the agent harness around it. How much of a coding agent's score belongs to the harness?"
        chips={
          <>
            <Chip s="solid">Direction clears zero</Chip>
            <Chip s="wide">Per-model magnitudes are wide</Chip>
          </>
        }
        meta={[
          ["Paired runs", `${b.pairedRuns} (${b.pairedDates[0]})`],
          ["Paired cells", `${p.cells} (eval × model)`],
          ["Harness sweep", `${b.harnessRuns} runs, ${b.harnessEvals} evals`],
          ["Harnesses", `${hs.length}`],
          ["Scoring", "run the produced code against a rubric"],
          ["Venue", "OpenRouter (open weights)"],
        ]}
        toc={[
          ["summary", "Summary"],
          ["method", "Method"],
          ["paired", "aider vs squeezer"],
          ["eight", "Eight harnesses"],
          ["limits", "Limitations"],
          ["data", "Data"],
        ]}
      />
      <div className="col-wide">
        <Keys
          items={[
            { v: `+${p.diff.toFixed(1)}`, l: `points for aider over the squeezer loop, paired over ${p.cells} cells`, s: `95% CI +${p.lo} to +${p.hi}` },
            ...weak.map((m) => ({ v: `${m.bMean.toFixed(0)} → ${m.aMean.toFixed(0)}`, l: `${m.label}: squeezer → aider`, s: `${m.cells} cells; CI on the gap ${m.lo?.toFixed(0)} to ${m.hi?.toFixed(0)}` })),
            { v: "tie", l: `${strong.map((m) => m.label).join(" and ")} score 100 under both`, s: "only 2 shared cells each" },
          ]}
        />
      </div>
      <div className="col prose">
        <h2 id="summary">Summary</h2>
        <p>
          On identical weights, switching from our minimal tool-calling loop to aider&apos;s edit format moved weak models by 60 points or
          more, while strong models scored 100 either way. The weaker the model, the bigger the harness swing. Any claim about the
          &ldquo;best model&rdquo; for coding has to name the harness it ran under.
        </p>
        <p>
          With a strong model the harness matters much less: {hs.filter((a) => a.model === "deepseek-v4-pro").length} agent harnesses on
          deepseek-v4-pro (plus {hs.filter((a) => a.model !== "deepseek-v4-pro").length} vendor CLIs on their own models) all land between {Math.min(...hs.map((a) => a.mean)).toFixed(0)}% and {Math.max(...hs.map((a) => a.mean)).toFixed(0)}% with
          overlapping intervals.
        </p>

        <h2 id="method">Method</h2>
        <ul>
          <li>
            Each task is a prompt plus a rubric that runs the code the agent produced and checks behaviour; a program that looks right but
            returns wrong answers loses most of its points. See <Link href="/methods/#scoring">Methods</Link>.
          </li>
          <li>
            <strong>squeezer</strong> is our ~250-line reference agent: four tools (read, write, list, bash) in a plain tool-calling loop. It is
            transparent and hackable, not a claimed best agent. <strong>aider</strong> edits through whole-file and diff formats instead of
            tool calls.
          </li>
          <li>
            The first bake-off was unpaired (a resume bug let one arm run far more cells than the other). The comparison here uses only the
            (eval, model) cells where <em>both</em> harnesses ran: each side&apos;s mean over its trials in that cell, then the paired difference.
            The 95% interval is a bootstrap over cells, computed when this site is built.
          </li>
        </ul>

        <h2 id="paired">aider vs the squeezer loop, paired</h2>
      </div>
      <div className="col-wide">
        <Figure
          n="1"
          title="Mean score per model under each harness, shared cells only"
          sub="Same model, same evals, only the harness changes."
          caption={<>Source: <code>runs.jsonl</code>, tag <code>bakeoff</code>, harnesses <code>aider-cloud</code> and <code>squeezer-cloud</code>.</>}
          table={
            <DataTable
              head={["model", "shared cells", "squeezer", "aider", "aider − squeezer", "95% CI", "aider wins / squeezer wins / ties"]}
              right={[1, 2, 3, 4, 5]}
              rows={[p, ...b.perModel].map((m) => [m.label, m.cells, m.bMean.toFixed(1), m.aMean.toFixed(1), m.diff.toFixed(1), fmtCI(m.lo, m.hi, 1), `${m.aWins} / ${m.bWins} / ${m.ties}`])}
            />
          }
        >
          <Legend
            items={[
              { c: "var(--mark-muted)", l: "squeezer (tool-calling loop)" },
              { c: "var(--mark)", l: "aider (edit format)" },
            ]}
          />
          <DotPlot rows={pairRows} domain={[0, 100]} ticks={[0, 25, 50, 75, 100]} axis="mean score %" />
        </Figure>

        <Figure
          n="2"
          title="The harness gap with its uncertainty"
          sub="aider minus squeezer, in points, with a bootstrap 95% interval over shared cells. Models with two cells have no spread to resample."
          caption="Interval: 2,000 resamples of the per-cell differences, seeded. The pooled interval clears zero; mistral-small-3.2's does not."
        >
          <DotPlot rows={deltaRows} domain={[-20, 100]} ticks={[-20, 0, 20, 40, 60, 80, 100]} axis="aider − squeezer, points" zero />
        </Figure>
      </div>

      <div className="col prose">
        <p>
          Over the {p.cells} shared cells aider averages {p.aMean.toFixed(1)}% against {p.bMean.toFixed(1)}% for squeezer, and wins {p.aWins}{" "}
          cells to {p.bWins} with {p.ties} ties. The likely mechanism, seen in the earlier local runs: small models fail at exact-match edits
          and tool calls (they hallucinate the file contents they are replacing), and a whole-file edit format sidesteps that failure. This
          sweep did not test the mechanism directly.
        </p>

        <h2 id="eight">Eight harnesses on one strong model</h2>
        <p>
          A second sweep ran each harness on deepseek-v4-pro over the full suite. The squeezer row is the same model from the main cloud sweep
          (a different run, same tasks). Codex CLI and Claude Code are vendor CLIs and ran their own vendors&apos; models, so they are drawn
          hollow and are not a harness-only comparison.
        </p>
      </div>
      <div className="col-wide">
        <Figure
          n="3"
          title="Mean score by harness, deepseek-v4-pro unless marked"
          sub="Mean of per-eval means; bars are cluster-bootstrap 95% intervals over evals."
          caption={
            <>
              Source: <code>runs.jsonl</code>, tag <code>harness-bakeoff</code>; squeezer from tag <code>fable-hunt</code>. pi ran 11 evals only.
              Cost is not recorded for some harnesses (n/r).
            </>
          }
          table={
            <DataTable
              head={["harness", "model", "evals", "runs", "mean %", "95% CI", "$/task", "mean wall"]}
              right={[2, 3, 4, 5, 6, 7]}
              rows={hs.map((a) => [HARNESS_NAME[a.harness] ?? a.harness, a.model, a.evals, a.n, a.mean.toFixed(1), fmtCI(a.lo, a.hi, 1), fmtCost(a.costPerTask), `${a.wallMean}s`])}
            />
          }
        >
          <Legend
            items={[
              { c: "var(--mark)", l: "deepseek-v4-pro" },
              { c: "var(--mark)", l: "vendor CLI, own model", kind: "ring" },
            ]}
          />
          <DotPlot rows={harnessRows} domain={[80, 100]} ticks={[80, 85, 90, 95, 100]} axis="mean score % (axis starts at 80)" />
        </Figure>
      </div>

      <div className="col prose">
        <Note title="What this does and does not show" chip="wide">
          <p>
            The direction (harness choice matters most for weak models) is supported by a pooled interval that clears zero. The magnitudes
            are not: qwen3-coder-30b rests on {b.perModel.find((m) => m.label === "qwen3-coder-30b")?.cells} shared cells, and the strong-model
            tie on two cells each.
          </p>
        </Note>

        <h2 id="limits">Limitations</h2>
        <ul>
          <li>Coverage is uneven per model; the paired view throws away every unpaired cell.</li>
          <li>Sampling used provider defaults; temperature and seed were not pinned for these sweeps.</li>
          <li>The tasks are ours and lean algorithmic. A standard external benchmark has not been run yet.</li>
          <li>The coding-suite agent shell is not sandboxed: a model could read a rubric mid-run. Not observed, but not ruled out.</li>
          <li>All scores are after the June rubric audit, which rewrote 26 rubrics and re-scored every affected run (see Methods).</li>
        </ul>

        <h2 id="data">Data</h2>
        <p>
          <a href={fileHref("data/runs.jsonl")}>runs.jsonl</a>, one JSON object per run. Filter on <code>tag</code> = <code>bakeoff</code> or{" "}
          <code>harness-bakeoff</code>.
        </p>
        <pre>
          <code>{`bin/bakeoff-report --tag bakeoff          # the paired table
bin/cloud-report --tag harness-bakeoff    # the eight-harness sweep`}</code>
        </pre>
      </div>
    </>
  );
}
