"use client";
import { useEffect, useState } from "react";

// The Mac Studio venue: big local models (up to ~120 GB) as tool-calling agents on llama.cpp.
// A different benchmark from the coding suite (end-state checks on files/mail/browser tasks), so it
// reads its own data: studio.json, built by bin/studio-summary from studio/rows/.

type Pass = {
  tag: string; key: string; model: string; quant: string; gb: string; engine: string;
  tools: string; suite: string; status: string;
  tasks: number; expected_tasks: number; solved: number; wilson95: [number | null, number | null];
  checks_passed: number; checks_total: number;
  by_suite: Record<string, { solved: number; tasks: number }>;
  wall_min: number; tok_s_over_wall: number | null; decode_tok_s: number | null;
  tool_calls: number; tool_errors: number;
  fail_stops: Record<string, number>; failed_tasks: string[];
};
type Cmp = { name: string; n: number; a: number; b: number; diff: number; ci: [number, number]; verdict: string; note: string };
type Summary = {
  venue: { name: string; hardware: string; engine: string };
  status: string; note: string;
  exploration: Record<string, Pass[]>;
  comparisons: Cmp[];
  final: { state: string; seed_offset: number; tasks: number; models: Pass[]; comparisons: Cmp[] };
};

const GROUPS: [string, string, string][] = [
  ["leanx_week", "Screen: 37 tasks, lean+x", "Files, search, mail, messages and an intranet, plus run_python. Saturated at the top: two models solved all 37."],
  ["leanx_hard2", "HARD2: 15 harder tasks", "Dirty data, buried policy exceptions, multi-app joins, partial-failure recovery. Saturated too."],
  ["leanx_hard3", "HARD3: 12 long-horizon tasks", "Data behind per-item calls, 60-110-call ledgers, refusals. Checkers were fixed between these two runs (see the findings), so the gap is not clean."],
  ["lean_week", "No code execution (lean+), 37 tasks", "The same screen without run_python. Kept as the paired baseline for the code-execution effect."],
  ["pi_week", "pi harness, 30 tasks", "bash/read/write/edit only; no mail or browser tools, so 30 of the 37."],
  ["smoke", "5-task smoke checks", "Load-and-work checks for models whose full rows come from the final pass, or that were dropped."],
];

const STOP_NOTE: Record<string, string> = {
  done: "claimed done, checks failed",
  out_of_tokens: "hit the reply cap",
  repeat_loop: "repeated the same call",
  empty_reply: "empty reply (unparsed tool call)",
  request_error: "server error",
  max_steps: "ran out of steps",
};

const pct = (x: number | null) => (x === null ? "-" : `${Math.round(x * 100)}`);

function SolvedBar({ p }: { p: Pass }) {
  const frac = p.tasks ? p.solved / p.tasks : 0;
  const [lo, hi] = p.wilson95;
  return (
    <div className="flex items-center gap-2 min-w-[180px]">
      <div className="relative h-2.5 flex-1 rounded bg-[var(--panel-2)] overflow-hidden" title={`95% Wilson interval ${pct(lo)}-${pct(hi)}%`}>
        {lo !== null && hi !== null && (
          <div className="absolute inset-y-0 bg-[color-mix(in_srgb,var(--accent)_22%,transparent)]"
               style={{ left: `${lo * 100}%`, width: `${(hi - lo) * 100}%` }} />
        )}
        <div className="absolute inset-y-0 left-0 bg-[var(--accent)]" style={{ width: `${frac * 100}%`, opacity: 0.85 }} />
      </div>
      <span className="tabular-nums text-xs w-12 text-right font-semibold">{p.solved}/{p.tasks}</span>
    </div>
  );
}

function PassTable({ rows }: { rows: Pass[] }) {
  return (
    <div className="overflow-x-auto bg-[var(--panel)] border border-[var(--border)] rounded-xl">
      <table className="w-full text-sm">
        <thead>
          <tr className="text-[10px] uppercase tracking-wider text-[var(--muted)] border-b border-[var(--border)]">
            <th className="text-left px-4 py-2">model</th>
            <th className="text-left px-2 py-2">quant</th>
            <th className="text-left px-2 py-2">solved (band = 95% CI)</th>
            <th className="text-right px-2 py-2">checks</th>
            <th className="text-left px-2 py-2">misses</th>
            <th className="text-right px-2 py-2">wall</th>
            <th className="text-right px-4 py-2" title="llama.cpp decode rate where reported, else completion tokens over wall time (*)">tok/s</th>
          </tr>
        </thead>
        <tbody className="tabular-nums">
          {rows.map((p) => (
            <tr key={p.tag} className="border-b border-[var(--border)] last:border-0 align-top">
              <td className="px-4 py-2 text-xs">
                <span className="font-mono">{p.model}</span>
                {p.status !== "done" && <span className="chip ml-2">partial</span>}
                {p.engine !== "llama.cpp" && <span className="block text-[10px] text-[var(--faint)]">{p.engine}</span>}
              </td>
              <td className="px-2 py-2 text-xs text-[var(--muted)] whitespace-nowrap">{p.quant}</td>
              <td className="px-2 py-2"><SolvedBar p={p} /></td>
              <td className="px-2 py-2 text-right text-xs text-[var(--muted)]">{p.checks_passed}/{p.checks_total}</td>
              <td className="px-2 py-2 text-xs text-[var(--muted)]" title={p.failed_tasks.join(", ")}>
                {Object.entries(p.fail_stops).map(([k, v]) => (
                  <span key={k} className="mr-2 whitespace-nowrap" title={STOP_NOTE[k] ?? k}>{k} {v}</span>
                ))}
                {!Object.keys(p.fail_stops).length && <span className="text-[var(--faint)]">-</span>}
              </td>
              <td className="px-2 py-2 text-right text-xs text-[var(--muted)] whitespace-nowrap">{Math.round(p.wall_min)} min</td>
              <td className="px-4 py-2 text-right text-xs text-[var(--muted)]">
                {p.decode_tok_s ?? (p.tok_s_over_wall !== null ? `${p.tok_s_over_wall}*` : "-")}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function CmpTable({ rows }: { rows: Cmp[] }) {
  return (
    <div className="overflow-x-auto bg-[var(--panel)] border border-[var(--border)] rounded-xl">
      <table className="w-full text-sm">
        <thead>
          <tr className="text-[10px] uppercase tracking-wider text-[var(--muted)] border-b border-[var(--border)]">
            <th className="text-left px-4 py-2">A vs B</th>
            <th className="text-right px-2 py-2">tasks</th>
            <th className="text-right px-2 py-2">A</th>
            <th className="text-right px-2 py-2">B</th>
            <th className="text-right px-2 py-2">A-B [95% CI]</th>
            <th className="text-left px-4 py-2">verdict</th>
          </tr>
        </thead>
        <tbody className="tabular-nums">
          {rows.map((c) => {
            const called = c.verdict === "A ahead" || c.verdict === "B ahead";
            return (
              <tr key={c.name} className="border-b border-[var(--border)] last:border-0">
                <td className="px-4 py-2 text-xs" title={c.note}>{c.name}</td>
                <td className="px-2 py-2 text-right text-xs text-[var(--muted)]">{c.n}</td>
                <td className="px-2 py-2 text-right text-xs">{c.a}</td>
                <td className="px-2 py-2 text-right text-xs">{c.b}</td>
                <td className="px-2 py-2 text-right text-xs whitespace-nowrap">
                  {c.diff >= 0 ? "+" : ""}{c.diff} <span className="text-[var(--faint)]">[{c.ci[0]}, {c.ci[1]}]</span>
                </td>
                <td className={`px-4 py-2 text-xs ${called ? "text-[var(--good)]" : "text-[var(--muted)]"}`}>{c.verdict}</td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

const BUGS: [string, string][] = [
  ["Grammar forces key order", "llama.cpp's tool-call grammar only accepts keys in schema order; a schema with glob after dst meant gpt-oss could never send it, and looped."],
  ["Mail search ignored ( )", "The Gmail mock returned 0 hits for grouped queries; the model concluded the mailbox was empty."],
  ["Cut-off tool call executed", "A reply truncated mid-call was sent back as broken JSON and killed the trial with HTTP 500."],
  ["Tool exception crashed the worker", "The task reran silently from scratch: a hidden second try that turned two fails into passes."],
  ["Checkers crashed on __pycache__", "Models that tested their own code left bytecode behind; good behaviour scored as a fail."],
  ["\"File-management agent\"", "The system prompt's wording made gpt-oss decline an email task as outside its tools."],
  ["Reasoning off for Mistral", "The chat template defaulted reasoning to none: 1 of 993 turns reasoned, 12/37."],
  ["235B out of memory at 131k", "Ran at 65k context with q8 KV instead; not the same context as the rest."],
  ["run_python could read the harness", "Checkers and reference answers were mounted where code ran. Unused (702 calls scanned); now a per-call jail."],
  ["World clock vs host clock", "The simulated world is fixed at 2026-10-28; a model used the real date and archived the wrong mail. Final pass restarted."],
  ["HARD3 checker bugs", "A code checker without the data files, a prompt naming a spec that was never written, a numbered REFUSED line not counted."],
];

export default function StudioPage() {
  const [s, setS] = useState<Summary | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    // trailingSlash is on: this page is /studio/, the data sits at the site root.
    fetch(`../studio.json?t=${Date.now()}`, { cache: "no-store" })
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(`HTTP ${r.status}`))))
      .then(setS)
      .catch((e) => setErr(String(e)));
  }, []);

  const fin = s?.final;
  const finDone = fin ? fin.models.filter((m) => m.status === "done") : [];

  return (
    <main>
      <section className="max-w-7xl mx-auto px-6 pt-10 pb-4">
        <div className="flex items-center gap-3 mb-2 flex-wrap">
          <span className="text-[10px] uppercase tracking-[0.25em] text-[var(--muted)]">local venue · Mac Studio M5 Max, 128 GB · agentic tool calling</span>
        </div>
        <h1 className="text-3xl md:text-5xl font-bold tracking-tight gradient-text leading-[1.04]">
          Which big local model is the best agent?
        </h1>
        <p className="text-[var(--muted)] text-base mt-3 max-w-3xl leading-relaxed">
          Open-weight models up to ~120 GB, one at a time on llama.cpp with 131k context, as tool-calling agents:
          files, search, a mailbox, messages and an intranet, scored on the <b className="text-[var(--text)]">end state</b>{" "}
          (what is on disk and in the mailbox), not on what the model says it did. A separate track from the coding suite,
          so scores do not compare with the other pages. Write-up:{" "}
          <a href="https://github.com/noahjohnson0/lemon-squeezer/blob/main/FINDINGS-STUDIO.md" className="text-[var(--accent)] hover:underline">FINDINGS-STUDIO.md</a>.
        </p>
      </section>

      <section className="max-w-7xl mx-auto px-6 mt-2">
        <div className="border border-[var(--mid)] rounded-xl px-5 py-4 text-sm bg-[color-mix(in_srgb,var(--mid)_8%,transparent)]">
          <b className="text-[var(--mid)]">Exploration, final pass {fin?.state ?? "pending"}.</b>{" "}
          <span className="text-[var(--muted)]">
            One trial per task, and the harness was being fixed while these ran, so this is a screen, not a ranking.
            The result is the final pass: frozen harness, all {fin?.tasks ?? 64} tasks, fresh workspaces, one pass per model.
          </span>
        </div>
      </section>

      {err && <p className="max-w-7xl mx-auto px-6 mt-6 text-sm text-[var(--bad)]">Could not load studio.json: {err}</p>}

      {fin && (
        <section className="max-w-7xl mx-auto px-6 mt-10">
          <div className="flex items-baseline gap-3 mb-2 flex-wrap">
            <h2 className="text-xl font-semibold">Final pass</h2>
            <span className="chip">{finDone.length}/7 models done</span>
          </div>
          {fin.models.length === 0 ? (
            <p className="text-[var(--muted)] text-sm">Running; nothing from it is reported yet.</p>
          ) : (
            <>
              <p className="text-[var(--muted)] text-sm max-w-3xl mb-4">
                A model&apos;s score shows once its pass is done; until then only its progress.
              </p>
              <div className="flex flex-wrap gap-3 mb-4">
                {fin.models.filter((m) => m.status !== "done").map((m) => (
                  <div key={m.tag} className="bg-[var(--panel)] border border-[var(--border)] rounded-xl px-4 py-3 text-xs">
                    <div className="font-mono">{m.model}</div>
                    <div className="text-[var(--muted)] mt-1">{m.tasks}/{m.expected_tasks} tasks run</div>
                  </div>
                ))}
              </div>
              {finDone.length > 0 && <PassTable rows={finDone} />}
              {fin.comparisons.length > 0 && <div className="mt-4"><CmpTable rows={fin.comparisons} /></div>}
            </>
          )}
        </section>
      )}

      {s && GROUPS.filter(([k]) => s.exploration[k]?.length).map(([k, title, blurb]) => (
        <section key={k} className="max-w-7xl mx-auto px-6 mt-10">
          <div className="flex items-baseline gap-3 mb-2 flex-wrap">
            <h2 className="text-xl font-semibold">{title}</h2>
            <span className="chip">exploration</span>
          </div>
          <p className="text-[var(--muted)] text-sm max-w-3xl mb-4">{blurb}</p>
          <PassTable rows={s.exploration[k]} />
        </section>
      ))}

      {s && s.comparisons.length > 0 && (
        <section className="max-w-7xl mx-auto px-6 mt-10">
          <div className="flex items-baseline gap-3 mb-2 flex-wrap">
            <h2 className="text-xl font-semibold">Paired comparisons</h2>
            <span className="chip">bootstrap over tasks</span>
          </div>
          <p className="text-[var(--muted)] text-sm max-w-3xl mb-4">
            Same tasks, two setups; 95% CI on the difference in tasks solved. &quot;Too wide to call&quot; when it includes zero,
            which with one trial per task is most of them.
          </p>
          <CmpTable rows={s.comparisons} />
        </section>
      )}

      <section className="max-w-7xl mx-auto px-6 mt-10">
        <h2 className="text-xl font-semibold mb-2">Harness bugs found on the way</h2>
        <p className="text-[var(--muted)] text-sm max-w-3xl mb-4">
          About half of the first day&apos;s failures were the harness, not the model. Each was fixed with a test before the final pass.
        </p>
        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {BUGS.map(([t, d]) => (
            <div key={t} className="bg-[var(--panel)] border border-[var(--border)] rounded-xl px-4 py-3">
              <div className="text-sm font-semibold">{t}</div>
              <div className="text-xs text-[var(--muted)] mt-1 leading-relaxed">{d}</div>
            </div>
          ))}
        </div>
      </section>

      <footer className="max-w-7xl mx-auto px-6 mt-16 mb-8 pt-6 border-t border-[var(--border)] text-xs text-[var(--muted)] flex flex-wrap gap-3 items-center justify-between">
        <div>
          rows:{" "}
          <a href="https://github.com/noahjohnson0/lemon-squeezer/tree/main/studio/rows" className="text-[var(--accent)] hover:underline">
            studio/rows
          </a>{" "}· rebuilt by <code>bin/studio-summary</code>
        </div>
        <div>{s?.venue.hardware}</div>
      </footer>
    </main>
  );
}
