import type { Metadata } from "next";
import fs from "node:fs";
import path from "node:path";
import { studio, totals } from "@/lib/site-data";
import { fileHref } from "@/components/ui";

export const metadata: Metadata = {
  title: "Data",
  description: "Download the run data every number on this site is computed from.",
};

function size(f: string) {
  try {
    const b = fs.statSync(path.join(process.cwd(), "public", "data", f)).size;
    return b > 1e6 ? `${(b / 1e6).toFixed(1)} MB` : `${Math.max(1, Math.round(b / 1e3))} KB`;
  } catch {
    return "";
  }
}

export default function Data() {
  const t = totals();
  const s = studio();
  const nRows = Object.values(s.exploration).reduce((a, v) => a + v.reduce((b, r) => b + r.tasks, 0), 0);
  const files = [
    {
      f: "runs.jsonl",
      d: `The coding suite: ${t.runs.toLocaleString("en-US")} runs, one JSON object per line (eval, harness, model, tag, host, score, tokens, wall time, cost, and GPU telemetry for local runs), from the 12 GB GPU, a laptop and cloud endpoints. Source of the harness bake-off, the cloud comparison and the 12 GB GPU study.`,
    },
    {
      f: "studio-summary.json",
      d: "The tool-calling screen, aggregated: every exploration table (solved, Wilson interval, checks, stop reasons, wall time, throughput), every paired comparison and the final-pass state.",
    },
    {
      f: "studio-rows.jsonl",
      d: `The tool-calling screen, one row per task (${nRows} exploration rows plus any final-pass rows): model, task, suite, checks passed, solved, steps, tool calls and errors, tokens, timings, stop reason and failed check names. The tag field says which pass a row belongs to.`,
    },
    { f: "studio-tags.json", d: "Which tool-calling passes are finished and which are partial." },
    {
      f: "bench-data.json",
      d: "Retrieval-augmented question answering sweeps over local document corpora. Not yet written up as a study.",
    },
  ];
  return (
    <>
      <header className="study-head col-wide">
        <div className="col" style={{ marginLeft: 0 }}>
          <div className="kicker">Data</div>
          <h1>Download the data</h1>
          <p className="dek">
            Every number on this site is computed from these files when the site is built. Nothing is typed in by hand. Rebuild the site from
            the repository and you get the same numbers.
          </p>
        </div>
      </header>
      <div className="col prose">
        <ul className="dl-list">
          {files.map((x) => (
            <li key={x.f}>
              <a className="f" href={fileHref(`data/${x.f}`)} download>
                {x.f}
              </a>
              <span className="sz">{size(x.f)}</span>
              <span className="d">{x.d}</span>
            </li>
          ))}
        </ul>
        <h2>Notes</h2>
        <ul>
          <li>Machine-specific strings (home-directory paths, internal host names) are stripped from the published copies. No values are changed.</li>
          <li>
            Scores in <code>runs.jsonl</code>{" "}are 0 to 100. A score of <code>&quot;?&quot;</code>{" "}marks a run whose rubric output could not be
            parsed; the site counts it as 0.
          </li>
          <li>Latest coding-suite run: {t.newest}. The tool-calling data is refreshed from its own harness as passes finish.</li>
          <li>License: MIT, like the code.</li>
        </ul>
        <h2>Reproduce</h2>
        <pre>
          <code>{`git clone https://github.com/noahjohnson0/lemon-squeezer
cd lemon-squeezer
bin/cloud-report --tag fable-hunt --by-eval   # cloud comparison
bin/bakeoff-report --tag bakeoff              # paired harness bake-off
bin/studio-summary                            # tool-calling tables
cd dashboard-next && bun install && bun run build   # this site`}</code>
        </pre>
      </div>
    </>
  );
}
