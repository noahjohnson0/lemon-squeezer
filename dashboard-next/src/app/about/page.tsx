import type { Metadata } from "next";
import Link from "next/link";
import { DataTable } from "@/components/ui";

export const metadata: Metadata = {
  title: "About",
  description: "lemon-squeezer has two tracks: benchmarks of open-weight models on hardware a person can own, and research on new methods.",
};

export default function About() {
  return (
    <>
      <header className="study-head col-wide">
        <div className="col" style={{ marginLeft: 0 }}>
          <div className="kicker">About</div>
          <h1>About lemon-squeezer</h1>
          <p className="dek">
            lemon-squeezer is an independent project on open-weight language models that run on hardware a person can own. It has two tracks,
            and each track has one goal.
          </p>
        </div>
      </header>
      <div className="col prose">
        <h2>Benchmarks</h2>
        <p>
          The goal of the benchmarks track is to say what works locally, on which hardware, for which job. The jobs so far are coding agents
          and tool calling. A benchmark claim is a ranking or a recommendation, and it comes with an interval, a cost and a speed. The work is
          meant to be practical, reproducible and current, and it does not need to be new. A known result measured again on this year&apos;s
          models is still useful to someone choosing what to run.
        </p>
        <p>
          The variables are the model, the agent harness around it, its configuration (quantization, reasoning effort, tools) and the venue it
          runs on. The <Link href="/studies/">studies</Link> report them with their methods, limits and raw rows.
        </p>

        <h2>Research</h2>
        <p>
          The goal of the research track is to find and report effects that are not already published. The current lines are on the Apple
          Neural Engine, on mixture-of-experts routing and pruning, and on agents for system administration. A research claim is published
          when it has passed a related-work check, shows an effect with an interval and has been replicated. Until then a line is listed on
          the <Link href="/research/">Research</Link> page with its question and its status, and no result is stated for it.
        </p>

        <h2>Rules for both tracks</h2>
        <ul>
          <li>A run is scored by executing code or checking end state. A model&apos;s own report and another model&apos;s opinion are never scored.</li>
          <li>The question and the analysis are written down before the runs, and every later change is logged as a dated amendment.</li>
          <li>Every difference is reported with an interval, and it is called too wide to call when the interval includes zero.</li>
          <li>The per-task rows are published along with the summary.</li>
          <li>Harness bugs are logged and published with their effect on the scores.</li>
        </ul>
        <p>
          The details are on the <Link href="/methods/">Methods</Link>{" "}page.
        </p>

        <h2>Hardware</h2>
        <p>All local runs use one machine at a time, one model at a time.</p>
        <DataTable
          head={["venue", "memory", "engine", "used for"]}
          rows={[
            ["Desktop GPU (RTX 4070 Super)", "12 GB VRAM", "Ollama", "coding suite, power and speed telemetry"],
            ["Laptop (Apple M4 Max)", "48 GB unified", "Ollama, llama.cpp", "a few coding-suite smoke runs; earlier tool-calling pilots"],
            ["Workstation (Apple M5 Max)", "128 GB unified, 120 GB GPU limit", "llama.cpp, MLX", "big-model tool-calling screen"],
            ["Rented endpoints", "n/a", "OpenRouter providers", "cloud model comparison and harness bake-off"],
          ]}
        />
        <p className="small muted">
          Cloud runs rent the same open weights from third-party providers and pay per token.
        </p>

        <h2>Corrections</h2>
        <p>
          When new data or an audit changes a published number, the page shows the new number and states what changed. Earlier write-ups stay
          in the repository with a note that they are historical. Report a problem by opening an issue on the{" "}
          <a href="https://github.com/noahjohnson0/lemon-squeezer/issues">repository</a>.
        </p>
      </div>
    </>
  );
}
