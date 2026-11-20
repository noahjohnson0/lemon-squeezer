import type { Metadata } from "next";
import Link from "next/link";
import { DataTable } from "@/components/ui";

export const metadata: Metadata = {
  title: "About the lab",
  description: "An independent lab studying open-weight language models as agents on hardware a person can own.",
};

export default function About() {
  return (
    <>
      <header className="study-head col-wide">
        <div className="col" style={{ marginLeft: 0 }}>
          <div className="kicker">About</div>
          <h1>About the lab</h1>
          <p className="dek">
            lemon-squeezer is the publishing arm of a small, independent research program on open-weight language models: how to make them
            faster, more accurate and better at agentic work on hardware a person can own.
          </p>
        </div>
      </header>
      <div className="col prose">
        <h2>What we study</h2>
        <p>
          The program&apos;s question is practical: given a model you can download and a machine you can buy, how much real work can you get
          out of it, and what moves that number? The variables we control are the model, the agent harness around it, its configuration
          (quantization, reasoning effort, tools) and the venue it runs on. Results get published here when a study has data worth reading,
          with its method, its limits and its raw rows.
        </p>
        <p>Lines of work in the program, published here as they reach that bar:</p>
        <ul>
          <li>Open models as tool-calling and coding agents (the studies on this site).</li>
          <li>A multi-host system-administration benchmark for agents.</li>
          <li>Mixture-of-experts internals: routing, expert pruning, adding experts.</li>
          <li>Running parts of models on unusual hardware, such as a laptop&apos;s neural engine.</li>
        </ul>

        <h2>How we work</h2>
        <ul>
          <li>Score by executing code or checking end state, never by a model&apos;s own report or another model&apos;s opinion.</li>
          <li>Preregister the question and analysis; log every change as a dated amendment.</li>
          <li>Report intervals, and say &ldquo;too wide to call&rdquo; when they include zero.</li>
          <li>Publish the rows, not only the summary.</li>
          <li>Treat harness bugs as findings and publish them.</li>
        </ul>
        <p>
          The details are on the <Link href="/methods/">Methods</Link> page.
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
          When new data or an audit changes a published number, the page shows the new number and says what changed. Earlier write-ups stay in
          the repository with a note that they are historical. Report a problem by opening an issue on the{" "}
          <a href="https://github.com/noahjohnson0/lemon-squeezer/issues">repository</a>.
        </p>
      </div>
    </>
  );
}
