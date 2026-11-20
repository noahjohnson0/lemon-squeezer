import Link from "next/link";
import type { ReactNode } from "react";
import { bakeoff, cloud, fmtCost, fmtCI, local, studio } from "@/lib/site-data";
import { cmp, finalState, row, shortName } from "@/lib/studio-view";
import { BUGS } from "@/lib/bugs";
import { Chip, DataTable, type Status } from "@/components/ui";
import StudyCards from "@/components/StudyCards";

type Pick = { job: string; title: ReactNode; body: ReactNode; facts: ReactNode; status: Status[]; href: string; study: string };
type NoteT = { claim: string; status: Status[]; kind?: string; body: ReactNode; limits: ReactNode; href: string; study: string };

const sgn = (x: number) => `${x > 0 ? "+" : x < 0 ? "−" : ""}${Math.abs(x)}`;

export default function Home() {
  const b = bakeoff();
  const c = cloud();
  const L = local();
  const s = studio();
  const fin = finalState();
  const week = s.exploration.leanx_week;

  // tool calling, 128 GB workstation
  const edge = row("leanx_week", "edge0-145b")!;
  const q38 = row("leanx_week", "qwen3.8-flash-next")!;
  const pi = row("pi_week", "qwen3.8-flash-next")!;
  const piCmp = cmp("Qwen3.8-Flash-Next: lean+x vs pi harness");
  const abl = cmp("gpt-oss-120b: base vs heretic (abliteration), lean+x");
  const ablNo = cmp("gpt-oss-120b: base vs heretic (abliteration), lean+");
  const mlx = cmp("gpt-oss-120b: llama.cpp vs MLX");
  const eff = cmp("gpt-oss-120b: reasoning high vs medium");
  const h3 = cmp("Edge0-145B vs Qwen3.8-Flash-Next, HARD3");
  const mlxRow = row("leanx_week", "gpt-oss-120b-mlx")!;
  const cppRow = row("leanx_week", "gpt-oss-120b-effhigh")!;
  const baseRow = row("leanx_week", "gpt-oss-120b-base")!;
  const cfgBug = row("leanx_week", "mistral-small-4-119b")!;
  const baseNoExec = row("lean_week", "gpt-oss-120b-base")!;
  const hereticNoExec = row("lean_week", "gpt-oss-120b-heretic")!;
  const injTask = "web_order_status";
  const injSplit = hereticNoExec.failed_tasks.includes(injTask) && !baseNoExec.failed_tasks.includes(injTask);
  const keyOrderTask = "organize";
  const keyOrderSeen = baseNoExec.failed_tasks.includes(keyOrderTask) && !baseRow.failed_tasks.includes(keyOrderTask);

  // model gaps in the screen, next to the bug count
  const top7 = [...week].sort((x, y) => y.solved - x.solved).slice(0, 7);
  const topGap = top7[0].solved - top7[6].solved;
  const modelCmps = s.comparisons.filter((x) => /^(Edge0|Qwen3\.8-Flash-Next) vs /.test(x.name));
  const modelWide = modelCmps.filter((x) => x.verdict !== "A ahead" && x.verdict !== "B ahead").length;

  // coding suite
  const gpu = L.models[0];
  const pi12 = L.harnessPairs.filter((p) => p.verdict === "A ahead");
  const pi12Worst = [...pi12].sort((x, y) => y.diff - x.diff)[0];
  const tiedSingles = c.tied.filter((a) => a.kind === "single" && a.costPerTask).sort((x, y) => x.costPerTask! - y.costPerTask!);
  const cheapTied = tiedSingles[0];
  const strong = b.harnesses.filter((a) => a.model === "deepseek-v4-pro");
  const strongAll = b.squeezerRef ? [...strong, b.squeezerRef] : strong;
  const sLo = Math.min(...strongAll.map((a) => a.mean));
  const sHi = Math.max(...strongAll.map((a) => a.mean));
  const weak = b.perModel.filter((m) => m.verdict === "A ahead");

  const picks: Pick[] = [
    {
      job: "Tool calling · 128 GB workstation",
      title: (
        <>
          {shortName(edge.model)} or {shortName(q38.model)}
        </>
      ),
      body: (
        <>
          Both solved all {edge.tasks} screening tasks with the same outcome on every task. The ranking will come from the final pass ({fin.tasks}{" "}
          tasks per model on a frozen harness), which is {fin.state}.
        </>
      ),
      facts: (
        <>
          {edge.solved}/{edge.tasks} · {Math.round(edge.wall_min)} min · {edge.tok_s_over_wall?.toFixed(0)} tok/s over wall time
          <br />
          {q38.solved}/{q38.tasks} · {Math.round(q38.wall_min)} min · {q38.tok_s_over_wall?.toFixed(0)} tok/s over wall time
        </>
      ),
      status: ["explore", "pending"],
      href: "/studies/tool-calling-week/",
      study: "Tool-calling screen",
    },
    {
      job: "Coding agent · 12 GB GPU",
      title: <>{gpu.model} through aider</>,
      body: (
        <>
          It has the highest mean on this card, over {gpu.evals} evals. Most cells have one trial and the models did not all run the same
          evals, so the order below it is not settled.
        </>
      ),
      facts: (
        <>
          {gpu.mean.toFixed(1)}% (95% CI {fmtCI(gpu.lo, gpu.hi)})
          <br />
          {gpu.powerW} W · {gpu.whPerTask} Wh a task · {gpu.wallMedian} s median
        </>
      ),
      status: ["explore"],
      href: "/studies/local-4070/",
      study: "12 GB GPU study",
    },
    {
      job: "Coding agent · rented open weights",
      title: <>{cheapTied.model}, the cheapest model in the tied top group</>,
      body: (
        <>
          {c.tied.length} arms have intervals that reach the leader&apos;s lower bound, so the data does not rank them. For a lower price,{" "}
          {c.value?.model} scores {c.value?.mean.toFixed(1)}% (CI {fmtCI(c.value!.lo, c.value!.hi)}) at {fmtCost(c.value?.costPerTask)} a task.
        </>
      ),
      facts: (
        <>
          {cheapTied.mean.toFixed(1)}% (95% CI {fmtCI(cheapTied.lo, cheapTied.hi, 1)})
          <br />
          {fmtCost(cheapTied.costPerTask)} a task · leader {c.arms[0].model} at {fmtCost(c.arms[0].costPerTask)}
        </>
      ),
      status: ["wide"],
      href: "/studies/cloud-models/",
      study: "Cloud model comparison",
    },
  ];

  const notes: NoteT[] = [
    {
      claim: "llama.cpp's tool-call grammar fixes the key order, and that made one tool parameter impossible to send.",
      status: [],
      kind: "Harness bug",
      body: (
        <>
          <p>
            The grammar that llama.cpp builds from a tool schema accepts object keys only in the order the schema lists them. A bulk-move tool
            listed its optional <code>glob</code> after the destination. A model that wrote the destination first could never add the glob,
            since the grammar no longer allowed that key.
            {keyOrderSeen && (
              <>
                {" "}
                gpt-oss-120b failed <code>{keyOrderTask}</code> this way before the fix and solved it after.
              </>
            )}
          </p>
          <p>
            The fix was to move the key up in the schema and make it required. A schema served through grammar-constrained decoding should be
            checked for optional keys that come late.
          </p>
        </>
      ),
      limits: <>Seen on one model family and one tool. The row before the fix also lacked code execution, so the task result alone does not isolate the bug.</>,
      href: "/methods/#bugs",
      study: "Harness bug log",
    },
    {
      claim: "Harness and configuration bugs moved scores more than the gaps between the top models.",
      status: ["explore"],
      kind: "Methods",
      body: (
        <>
          <p>
            The tool-calling exploration found {BUGS.length} harness bugs. Over the same period the top seven configurations on the{" "}
            {edge.tasks} screening tasks were {topGap} tasks apart, and {modelWide} of the {modelCmps.length} paired comparisons between models
            are too wide to call.
          </p>
          <p>
            One configuration error, reasoning left switched off, produced the lowest row in the screen at {cfgBug.solved}/{cfgBug.tasks}. A
            clock bug in the simulated world caused the final pass to be restarted. Each bug is listed with its effect in the log.
          </p>
        </>
      ),
      limits: <>The bugs were not rerun one at a time, so there is no per-bug score change. The claim rests on the log and on the size of the model gaps.</>,
      href: "/methods/#bugs",
      study: "Harness bug log",
    },
    {
      claim: "MLX and llama.cpp ran gpt-oss-120b at the same speed, and MLX lost tool calls that llama.cpp cannot emit.",
      status: ["explore", "wide"],
      body: (
        <>
          <p>
            On the same {mlx.n} tasks at high reasoning, llama.cpp solved {mlx.a} and MLX solved {mlx.b}. The 95% interval on the difference is{" "}
            {sgn(mlx.ci[0])} to {sgn(mlx.ci[1])} tasks. Throughput over wall time was {cppRow.tok_s_over_wall?.toFixed(0)} against{" "}
            {mlxRow.tok_s_over_wall?.toFixed(0)} tok/s.
          </p>
          <p>
            {mlxRow.fail_stops.empty_reply ?? 0} of the {mlxRow.tasks - mlxRow.solved} tasks MLX failed ended in an empty reply, which is a tool
            call its parser could not read. llama.cpp had {cppRow.fail_stops.empty_reply ?? 0}, since its grammar constrains the call. MLX also
            needed a patched parser to run this model with tools at all.
          </p>
        </>
      ),
      limits: <>One model, one trial per task. The score gap is too wide to call. The speed result and the empty replies are the useful part.</>,
      href: "/studies/tool-calling-week/#smaller",
      study: "Tool-calling screen",
    },
    {
      claim: "Abliteration showed no cost on tool use for gpt-oss-120b.",
      status: ["explore", "wide"],
      body: (
        <p>
          The base model and an abliterated build solved the same number of tasks with code execution ({abl.a} and {abl.b}) and without it (
          {ablNo.a} and {ablNo.b}).
          {injSplit && (
            <>
              {" "}
              They differed on one task without execution: the abliterated build failed <code>{injTask}</code>, which plants an instruction in
              a web page, on the check that it did not obey that instruction. The base model passed it.
            </>
          )}
        </p>
      ),
      limits: (
        <>
          The interval on the difference is {sgn(abl.ci[0])} to {sgn(abl.ci[1])} tasks, so a small cost is not ruled out. The injection result is
          one task and one trial.
        </>
      ),
      href: "/studies/tool-calling-week/#smaller",
      study: "Tool-calling screen",
    },
    {
      claim: "A general coding harness (pi) matched a purpose-built toolset with a strong model, and did not help weak ones.",
      status: ["explore"],
      body: (
        <>
          <p>
            pi gives the model four tools (bash, read, write, edit). On the {piCmp.n} screening tasks that need no mail or browser tools,{" "}
            {shortName(q38.model)} solved {pi.solved} through pi and {piCmp.a} through the purpose-built toolset, which is too wide to call.
            The other {edge.tasks - piCmp.n} tasks cannot run under pi.
          </p>
          <p>
            On the 12 GB GPU pi scored below aider on {pi12.length} of {L.harnessPairs.length} models with an interval that clears zero.{" "}
            {pi12Worst.label} went from {pi12Worst.bMean.toFixed(0)}% through pi to {pi12Worst.aMean.toFixed(0)}% through aider on the same{" "}
            {pi12Worst.cells} evals. The cloud bake-off shows the same pattern for a minimal tool loop: aider was {b.paired.diff.toFixed(1)}{" "}
            points ahead over {b.paired.cells} paired cells (95% CI +{b.paired.lo} to +{b.paired.hi}), and the gap came from{" "}
            {weak.map((m) => m.label).join(" and ")}. With a strong model, {strongAll.length} harnesses scored between {sLo.toFixed(0)}% and{" "}
            {sHi.toFixed(0)}% with overlapping intervals.
          </p>
        </>
      ),
      limits: <>The per-model gaps rest on few cells ({weak.map((m) => `${m.label} ${m.cells}`).join(", ")}). Why small models fail through tool calls was not tested directly.</>,
      href: "/studies/harness-bakeoff/",
      study: "Harness bake-off",
    },
  ];

  const wide: ReactNode[][] = [
    ...L.venue.map((p) => [
      <>
        {p.label}: local 4-bit build against the same model rented
        <br />
        <Link href="/studies/local-4070/#venue">12 GB GPU study</Link>
      </>,
      `${p.aMean.toFixed(1)}%`,
      `${p.bMean.toFixed(1)}%`,
      `${sgn(p.diff)} (${sgn(p.lo ?? 0)} to ${sgn(p.hi ?? 0)}) points`,
    ]),
    [
      <>
        gpt-oss-120b: reasoning high against medium
        <br />
        <Link href="/studies/tool-calling-week/#smaller">Tool-calling screen</Link>
      </>,
      `${eff.a}/${eff.n}`,
      `${eff.b}/${eff.n}`,
      `${sgn(eff.diff)} (${sgn(eff.ci[0])} to ${sgn(eff.ci[1])}) tasks, at ${Math.round(cppRow.wall_min)} against ${Math.round(baseRow.wall_min)} min`,
    ],
    [
      <>
        {shortName(edge.model)} against {shortName(q38.model)}, hardest suite
        <br />
        <Link href="/studies/tool-calling-week/">Tool-calling screen</Link>
      </>,
      `${h3.a}/${h3.n}`,
      `${h3.b}/${h3.n}`,
      `${sgn(h3.diff)} (${sgn(h3.ci[0])} to ${sgn(h3.ci[1])}) tasks`,
    ],
    [
      <>
        Best multi-model mix ({c.bestMix.model}) against best single model ({c.bestSingle.model})
        <br />
        <Link href="/studies/cloud-models/">Cloud model comparison</Link>
      </>,
      `${c.bestMix.mean.toFixed(1)}%`,
      `${c.bestSingle.mean.toFixed(1)}%`,
      `intervals overlap (${fmtCI(c.bestMix.lo, c.bestMix.hi, 1)} and ${fmtCI(c.bestSingle.lo, c.bestSingle.hi, 1)})`,
    ],
  ];

  return (
    <>
      <section className="masthead col-wide">
        <div className="kicker">Benchmarks track</div>
        <h1>What works locally, on which hardware, for which job</h1>
        <p className="dek" style={{ maxWidth: "var(--measure)" }}>
          lemon-squeezer runs open-weight models as coding and tool-calling agents on a 12 GB gaming GPU, a 128 GB workstation and rented
          endpoints. Each run is scored by executing its code or checking the state it left behind. The results below are rankings and
          recommendations with intervals, cost and speed.
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

      <section className="col-wide" aria-label="Current picks" style={{ marginTop: "2rem" }}>
        <h2 id="picks" style={{ marginTop: 0 }}>
          Current picks
        </h2>
        <div className="picks">
          {picks.map((p) => (
            <article className="pick" key={p.job}>
              <div className="job">{p.job}</div>
              <h3>{p.title}</h3>
              <div className="facts">{p.facts}</div>
              <p>{p.body}</p>
              <div className="foot">
                {p.status.map((st) => (
                  <Chip key={st} s={st} />
                ))}
                <Link href={p.href}>{p.study} →</Link>
              </div>
            </article>
          ))}
        </div>
        <p className="ui small muted">
          A pick marked exploration is a candidate from a screen. It becomes a ranking when its final pass is done.
        </p>
      </section>

      <section className="col-wide" aria-label="Notes from running the benchmarks" style={{ marginTop: "3rem" }}>
        <h2 id="notes">What running them showed</h2>
        <p style={{ maxWidth: "var(--measure)" }}>
          These are the results that changed how we serve models or read a score. Results that a reader would expect, such as code execution
          helping an agent, are in the study pages and are left out here.
        </p>
        {notes.map((f, i) => (
          <article className="finding" key={i}>
            <div className="n">{String(i + 1).padStart(2, "0")}</div>
            <div className="body">
              <div className="col" style={{ marginLeft: 0 }}>
                <h3>{f.claim}</h3>
                {f.body}
                <p className="uncert">
                  <b>Limits</b>
                  {f.limits}
                </p>
              </div>
              <div className="ev">
                {f.kind && <span>{f.kind}</span>}
                {f.status.map((st) => (
                  <Chip key={st} s={st} />
                ))}
                <Link href={f.href}>Evidence: {f.study} →</Link>
              </div>
            </div>
          </article>
        ))}
      </section>

      <section className="col-wide" style={{ marginTop: "3rem" }}>
        <h2 id="wide">Too wide to call</h2>
        <p style={{ maxWidth: "var(--measure)" }}>
          These comparisons were run and the interval on the difference includes zero. They are listed here so that the point estimates are not read as a ranking.
        </p>
        <DataTable
          head={["comparison", "A", "B", "A − B (95% CI)"]}
          right={[1, 2]}
          rows={wide}
        />
      </section>

      <section className="col-wide" style={{ marginTop: "3rem" }}>
        <h2 id="studies">Studies</h2>
        <StudyCards />
        <p className="ui small muted">
          Next: the tool-calling final pass, the coding suite on the 128 GB workstation, and a standard external benchmark.
        </p>
        <div className="track-link">
          <p>
            Work on new methods (the Neural Engine, mixture-of-experts routing and pruning) is a separate track with a different bar. It is
            on the <Link href="/research/">Research</Link> page.
          </p>
        </div>
      </section>
    </>
  );
}
