import type { Metadata } from "next";
import Link from "next/link";
import { local, fmtCI } from "@/lib/site-data";
import { Chip, DataTable, DotPlot, Figure, Keys, Legend, Note, StudyHead, fileHref, type DotRow } from "@/components/ui";

export const metadata: Metadata = {
  title: "Coding agents on a 12 GB consumer GPU",
  description: "Quantized open models as coding agents on an RTX 4070 Super: scores, harness effects, power draw and a matched local-vs-cloud check.",
};

const short = (m: string) => m.replace("-a3b-q4_K_M", " (q4_K_M)");

export default function Page() {
  const L = local();
  const ranked = L.models.filter((m) => m.lo !== null);
  const unranked = L.models.filter((m) => m.lo === null);
  const moe = L.models.find((m) => m.model === "gpt-oss:20b")!;
  const dense = L.models.find((m) => m.model === "qwen3:14b")!;
  const q14pair = L.harnessPairs.find((p) => p.label === "qwen3:14b");

  const scoreRows: DotRow[] = ranked.map((m) => ({
    label: (
      <>
        {short(m.model)} <span className="s">· {m.evals} evals</span>
      </>
    ),
    title: `${m.model} via aider · ${m.evals} evals, ${m.n} runs · mean ${m.mean}% · CI ${fmtCI(m.lo, m.hi, 1)}`,
    v: m.mean,
    lo: m.lo,
    hi: m.hi,
    val: m.mean.toFixed(1),
    tone: m.model === moe.model ? "hi" : undefined,
  }));

  const powered = L.models.filter((m) => m.powerW !== null && m.lo !== null).sort((a, b) => a.powerW! - b.powerW!);
  const powerRows: DotRow[] = powered.map((m) => ({
    label: short(m.model),
    title: `${m.model}: mean GPU power ${m.powerW} W over ${m.telemetryN} runs; ${m.whPerTask} Wh per task`,
    v: m.powerW!,
    val: `${m.powerW} W`,
    tone: m.model === moe.model ? "hi" : undefined,
  }));

  const pairRows: DotRow[] = L.harnessPairs.map((p) => ({
    label: (
      <>
        {short(p.label)} <span className="s">· {p.cells} evals</span>
      </>
    ),
    title: `${p.label}: aider ${p.aMean}%, pi ${p.bMean}% on ${p.cells} shared evals; gap ${p.diff} [${p.lo}, ${p.hi}]`,
    v: p.aMean,
    b: p.bMean,
    val: `${p.bMean.toFixed(0)} → ${p.aMean.toFixed(0)}`,
  }));

  const venueRows: DotRow[] = L.venue.map((p) => ({
    label: (
      <>
        {p.label} <span className="s">· {p.cells} evals</span>
      </>
    ),
    title: `${p.label}: 4070 q4 ${p.aMean}% vs cloud ${p.bMean}%; difference ${p.diff} [${p.lo}, ${p.hi}]`,
    v: p.diff,
    lo: p.lo,
    hi: p.hi,
    val: `${p.diff > 0 ? "+" : ""}${p.diff.toFixed(1)}`,
  }));

  return (
    <>
      <StudyHead
        kicker="Study · coding agents · 12 GB consumer GPU"
        title="Coding agents on a 12 GB consumer GPU"
        dek="What does a quantized open model on an ordinary gaming card actually finish, through which harness, and at what power draw?"
        chips={
          <>
            <Chip s="explore">Early, small n</Chip>
            <Chip s="wide">Venue gap: too wide to call</Chip>
          </>
        }
        meta={[
          ["Hardware", "RTX 4070 Super, 12 GB"],
          ["Engine", "Ollama, 4-bit quantizations"],
          ["Runs", `${L.nRuns}`],
          ["Models", `${L.nModels}`],
          ["Evals touched", `${L.nEvals}`],
          ["Dates", `${L.dates[0]} to ${L.dates[1]}`],
        ]}
        toc={[
          ["summary", "Summary"],
          ["method", "Method"],
          ["scores", "Scores"],
          ["harness", "Harness"],
          ["power", "Power"],
          ["venue", "Local vs cloud"],
          ["limits", "Limitations"],
          ["data", "Data"],
        ]}
      />
      <div className="col-wide">
        <Keys
          items={[
            { v: `${moe.mean.toFixed(0)}%`, l: `${moe.model} through aider, ${moe.evals} evals`, s: `95% CI ${fmtCI(moe.lo, moe.hi)}` },
            { v: `${moe.powerW} W vs ${dense.powerW} W`, l: `mean GPU power: ${moe.model} (MoE) vs ${dense.model} (dense)`, s: `${moe.whPerTask} vs ${dense.whPerTask} Wh per task` },
            ...(q14pair ? [{ v: `${q14pair.bMean.toFixed(0)} → ${q14pair.aMean.toFixed(0)}`, l: `${q14pair.label}: pi → aider, same ${q14pair.cells} evals`, s: `CI on the gap +${q14pair.lo?.toFixed(0)} to +${q14pair.hi?.toFixed(0)}` }] : []),
          ]}
        />
      </div>
      <div className="col prose">
        <h2 id="summary">Summary</h2>
        <ul>
          <li>
            On a 12 GB card the mixture-of-experts model {moe.model} was both the best scorer through aider and among the lowest in GPU power,
            about a quarter of the dense {dense.model}&apos;s draw. Only a handful of its parameters are active per token.
          </li>
          <li>
            The harness effect from the cloud bake-off shows up locally too: the same weights score far higher through aider than through the
            pi agent on the evals both ran. Few evals per pair, but{" "}
            {L.harnessPairs.filter((p) => p.verdict === "A ahead").length} of {L.harnessPairs.length} intervals clear zero.
          </li>
          <li>
            Running a model as a 4-bit local build did not measurably lower its score against the same model served in the cloud, on the
            evals both ran. The intervals are wide (±20 points), so a small quantization cost is not ruled out.
          </li>
        </ul>
        <Note title="This is the oldest and thinnest venue" chip="explore">
          <p>
            These runs predate the pinned-sampling and paired-design rules used later. Models were not all run on the same evals, most cells
            have one trial, and the interval is only computed for models with at least 8 evals. The earliest write-up of this data
            (FINDINGS.md, May 2026) is kept in the repository as a historical snapshot.
          </p>
        </Note>

        <h2 id="method">Method</h2>
        <p>
          Each run is one agent working one eval through a harness (aider, pi, our squeezer loop or a multi-step pipeline) against a model
          served by Ollama on the card, serialized by a GPU lock so timing and power belong to one run. A sampler records GPU power,
          memory, utilisation and temperature once a second. The rubric then runs the produced code. Scores are the mean over evals of each
          eval&apos;s mean; intervals are a cluster bootstrap over evals. See <Link href="/methods/">Methods</Link>.
        </p>

        <h2 id="scores">Scores through aider</h2>
      </div>
      <div className="col-wide">
        <Figure
          n="1"
          title="Mean score by model, aider harness"
          sub="Cluster-bootstrap 95% intervals over evals. Models were run on different eval subsets (count shown), so rows are not on identical tasks."
          caption={
            <>
              Source: <code>runs.jsonl</code>, host 4070, harness <code>aider</code>.{" "}
              {unranked.length > 0 && <>Left out for having fewer than 8 evals: {unranked.map((m) => `${m.model} (${m.evals})`).join(", ")}.</>}
            </>
          }
          table={
            <DataTable
              head={["model", "evals", "runs", "mean %", "95% CI", "GPU W", "Wh/task", "VRAM peak", "median wall"]}
              right={[1, 2, 3, 4, 5, 6, 7, 8]}
              rows={L.models.map((m) => [m.model, m.evals, m.n, m.mean.toFixed(1), fmtCI(m.lo, m.hi, 1), m.powerW ?? "n/r", m.whPerTask ?? "n/r", m.vramPeakGB ? `${m.vramPeakGB} GB` : "n/r", `${m.wallMedian}s`])}
            />
          }
        >
          <DotPlot rows={scoreRows} domain={[0, 100]} ticks={[0, 25, 50, 75, 100]} axis="mean score %" />
        </Figure>
      </div>

      <div className="col prose">
        <h2 id="harness">Same weights, different harness</h2>
      </div>
      <div className="col-wide">
        <Figure
          n="2"
          title="pi vs aider on the same model and the same evals"
          sub="Grey: pi (exact-string edits). Blue: aider (whole-file edits). Only evals both harnesses ran."
          caption="Source: runs.jsonl, host 4070. Bootstrap intervals on each gap are in the table."
          table={
            <DataTable
              head={["model", "shared evals", "pi %", "aider %", "aider − pi", "95% CI", "verdict"]}
              right={[1, 2, 3, 4, 5]}
              rows={L.harnessPairs.map((p) => [p.label, p.cells, p.bMean.toFixed(1), p.aMean.toFixed(1), p.diff.toFixed(1), fmtCI(p.lo, p.hi, 1), <Chip key="v" s={p.verdict === "A ahead" ? "solid" : "wide"} />])}
            />
          }
        >
          <Legend
            items={[
              { c: "var(--mark-muted)", l: "pi" },
              { c: "var(--mark)", l: "aider" },
            ]}
          />
          <DotPlot rows={pairRows} domain={[0, 100]} ticks={[0, 25, 50, 75, 100]} axis="mean score % on shared evals" />
        </Figure>
      </div>

      <div className="col prose">
        <h2 id="power">Power draw</h2>
        <p>
          Peak VRAM is near the card&apos;s 12 GB for every model (the server fills the card), so memory does not separate them. Power does.
        </p>
      </div>
      <div className="col-wide">
        <Figure
          n="3"
          title="Mean GPU board power during a run"
          sub="Averaged over runs with telemetry. Lower is better at equal score."
          caption="Source: runs.jsonl telemetry.gpu_power_avg_w (1 Hz samples). Energy per task = mean power × wall time."
        >
          <DotPlot rows={powerRows} domain={[0, 200]} ticks={[0, 50, 100, 150, 200]} axis="watts" />
        </Figure>
      </div>

      <div className="col prose">
        <h2 id="venue">Local 4-bit vs the same model in the cloud</h2>
        <p>
          The same squeezer loop ran two models on the 4070 (Ollama, 4-bit) and through a cloud provider (higher precision) on the same evals.
          Each eval&apos;s local mean is paired with its cloud mean.
        </p>
      </div>
      <div className="col-wide">
        <Figure
          n="4"
          title="Local minus cloud, same model and evals"
          sub="Bootstrap 95% interval over evals. Both intervals include zero."
          caption={<>Source: runs.jsonl, harness squeezer-local ({L.venueLocalRuns} runs) vs squeezer-cloud tag fable-hunt.</>}
          table={
            <DataTable
              head={["model", "shared evals", "4070 q4 %", "cloud %", "difference", "95% CI"]}
              right={[1, 2, 3, 4, 5]}
              rows={L.venue.map((p) => [p.label, p.cells, p.aMean.toFixed(1), p.bMean.toFixed(1), p.diff.toFixed(1), fmtCI(p.lo, p.hi, 1)])}
            />
          }
        >
          <DotPlot rows={venueRows} domain={[-30, 30]} ticks={[-30, -15, 0, 15, 30]} axis="4070 q4 − cloud, points" zero />
        </Figure>
      </div>

      <div className="col prose">
        <Note title="A correction to an earlier write-up" chip="wide">
          <p>
            FINDINGS-CLOUD.md reported a 3 to 5 point &ldquo;quant tax&rdquo; for local 4-bit builds. Recomputed from the current runs with
            evals paired, the gap is {L.venue.map((p) => `${p.diff > 0 ? "+" : ""}${p.diff.toFixed(1)} (${p.label})`).join(" and ")}, with
            intervals about ±20 points wide. The data supports &ldquo;no detectable difference&rdquo;, not a measured tax.
          </p>
        </Note>

        <h2 id="limits">Limitations</h2>
        <ul>
          <li>Unequal eval coverage per model and mostly one trial per cell.</li>
          <li>Unpinned sampling (provider and Ollama defaults).</li>
          <li>Power is the GPU board only, not the whole machine.</li>
          <li>One card; results at other VRAM sizes are not measured here.</li>
        </ul>
        <h2 id="data">Data</h2>
        <p>
          <a href={fileHref("data/runs.jsonl")}>runs.jsonl</a>: rows with <code>host</code> = <code>4070</code> (or no host, for the oldest
          rows). Telemetry aggregates are under <code>telemetry</code>.
        </p>
        <pre>
          <code>{`bin/energy-report --by-model     # kWh and cost per model
bin/eval-list                    # local runs`}</code>
        </pre>
      </div>
    </>
  );
}
