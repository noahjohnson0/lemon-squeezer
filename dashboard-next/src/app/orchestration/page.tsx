"use client";
import { useEffect, useMemo, useState } from "react";
import { loadRuns, type Run } from "@/lib/data";
import OrchestrationFlow, { type Pattern } from "@/components/OrchestrationFlow";
import ConductorPanel from "@/components/ConductorPanel";

// The four orchestration patterns lemon-squeezer can run as "mixes" (several
// models wired over one workspace). Topology is fixed; the real results are
// merged in from runs.jsonl below. (Pattern data co-authored with kimi.)
const PATTERNS: Pattern[] = [
  {
    key: "architect", title: "Architect", tagline: "A strong model plans; a cheap one writes the code.",
    nodes: [{ id: "p", label: "planner", role: "planner" }, { id: "i", label: "implementer", role: "implementer" }],
    edges: [{ from: "p", to: "i", label: "plan" }],
  },
  {
    key: "critique", title: "Critique", tagline: "Draft, get reviewed, refine - on a loop.",
    nodes: [{ id: "i", label: "implementer", role: "implementer" }, { id: "c", label: "critic", role: "critic" }],
    edges: [{ from: "i", to: "c", label: "draft" }, { from: "c", to: "i", label: "refine" }],
  },
  {
    key: "ensemble", title: "Ensemble", tagline: "Several models each draft; a judge picks the best.",
    nodes: [
      { id: "a", label: "impl A", role: "implementer" }, { id: "b", label: "impl B", role: "implementer" },
      { id: "c", label: "impl C", role: "implementer" }, { id: "j", label: "judge", role: "judge" },
    ],
    edges: [{ from: "a", to: "j" }, { from: "b", to: "j" }, { from: "c", to: "j", label: "pick" }],
  },
  {
    key: "verify", title: "Verify", tagline: "Write code and its tests, then self-correct until they pass.",
    nodes: [{ id: "i", label: "implementer", role: "implementer" }, { id: "t", label: "tester", role: "tester" }],
    edges: [{ from: "i", to: "t", label: "test" }, { from: "t", to: "i", label: "fix" }],
  },
];

const isCloud = (r: Run) => (r.host ?? "4070") === "openrouter";
const fmtCost = (c: number) => (c >= 0.01 ? `$${c.toFixed(3)}` : `$${c.toFixed(5)}`);
const mean = (xs: number[]) => (xs.length ? xs.reduce((s, x) => s + x, 0) / xs.length : 0);

export default function OrchestrationPage() {
  const [runs, setRuns] = useState<Run[]>([]);
  useEffect(() => { loadRuns("../runs.jsonl").then(setRuns).catch(() => {}); }, []);

  // best single vs best mix, per the "do mixes actually help?" question, from real data.
  const { patterns, bestSingle, bestMix } = useMemo(() => {
    const cloud = runs.filter((r) => isCloud(r) && r.tag === "fable-hunt");
    // aggregate per arm (model|harness): mean of per-eval means
    type Agg = { model: string; harness: string; score: number; cost: number; n: number };
    const groups = new Map<string, Run[]>();
    for (const r of cloud) (groups.get(`${r.model}|${r.harness}`) ?? groups.set(`${r.model}|${r.harness}`, []).get(`${r.model}|${r.harness}`)!).push(r);
    const arms: Agg[] = [];
    for (const [k, rs] of groups) {
      const byEval = new Map<string, number[]>();
      for (const r of rs) { const v = Number.isFinite(r.score_pct) ? r.score_pct : 0; (byEval.get(r.eval) ?? byEval.set(r.eval, []).get(r.eval)!).push(v); }
      if (byEval.size < 8) continue;
      const [model, harness] = k.split("|");
      arms.push({ model, harness, score: mean([...byEval.values()].map(mean)), cost: mean(rs.map((r) => r.cost_usd ?? 0)), n: rs.length });
    }
    const isMix = (h: string) => h.startsWith("cloud-") && h !== "squeezer-cloud";
    const best = (pred: (a: Agg) => boolean) => arms.filter(pred).sort((a, b) => b.score - a.score)[0];
    const merged = PATTERNS.map((p) => {
      const arm = best((a) => a.harness === `cloud-${p.key}`);
      return arm ? { ...p, result: { arm: arm.model, score: Math.round(arm.score * 10) / 10, cost: Math.round(arm.cost * 1e5) / 1e5 } } : p;
    });
    return { patterns: merged, bestSingle: best((a) => a.harness === "squeezer-cloud"), bestMix: best((a) => isMix(a.harness)) };
  }, [runs]);

  return (
    <main>
      <section className="max-w-7xl mx-auto px-6 pt-10 pb-4">
        <span className="text-[10px] uppercase tracking-[0.25em] text-[var(--muted)]">orchestration · multi-model mixes &amp; agent frameworks</span>
        <h1 className="text-3xl md:text-5xl font-bold tracking-tight gradient-text leading-[1.04] mt-2">
          When does wiring models together actually help?
        </h1>
        <p className="text-[var(--muted)] text-base mt-3 max-w-3xl leading-relaxed">
          A single model is one agent in a loop. A <b className="text-[var(--text)]">mix</b> wires several over one
          workspace - a planner, an implementer, a critic, a judge. lemon-squeezer runs four such patterns as harnesses
          and scores them on the same evals as everything else. Below: how each is wired, and what it actually buys.
        </p>
      </section>

      <section className="max-w-7xl mx-auto px-6 mt-4">
        <OrchestrationFlow patterns={patterns} />
      </section>

      {/* The honest verdict from the data */}
      {bestSingle && bestMix && (
        <section className="max-w-7xl mx-auto px-6 mt-12">
          <h2 className="text-xl font-semibold mb-2">Do mixes beat the best single model?</h2>
          <p className="text-[var(--muted)] text-sm max-w-3xl mb-4">
            Mostly no. The best single model already sits in the top cluster; the best mix matches it but costs more and
            runs slower. Mixes earn their keep <b className="text-[var(--text)]">rescuing weak models</b>, not raising the
            ceiling. Numbers from the main suite.
          </p>
          <div className="flex flex-wrap gap-3">
            <div className="card flex-1 min-w-[240px] p-5">
              <div className="text-[10px] uppercase tracking-[0.2em] text-[var(--muted)]">best single model</div>
              <div className="mt-1 font-mono text-[var(--text)]">{bestSingle.model}</div>
              <div className="text-3xl font-bold gradient-text tabular-nums">{bestSingle.score.toFixed(0)}%</div>
              <div className="text-xs text-[var(--muted)]">{fmtCost(bestSingle.cost)}/task</div>
            </div>
            <div className="card flex-1 min-w-[240px] p-5">
              <div className="text-[10px] uppercase tracking-[0.2em] text-[var(--muted)]">best mix</div>
              <div className="mt-1 font-mono text-[var(--accent)]">{bestMix.model}</div>
              <div className="text-3xl font-bold tabular-nums">{bestMix.score.toFixed(0)}%</div>
              <div className="text-xs text-[var(--muted)]">{fmtCost(bestMix.cost)}/task · {(bestMix.cost / Math.max(bestSingle.cost, 1e-9)).toFixed(1)}x the cost</div>
            </div>
          </div>
        </section>
      )}

      {/* Meta: this page was itself built by orchestration */}
      <section className="max-w-7xl mx-auto px-6 mt-12">
        <ConductorPanel />
        <p className="text-xs text-[var(--faint)] mt-3 max-w-3xl">
          This tab was built by one Claude conducting codex, kimi, and aider in parallel - the same idea as the mixes
          above, one level up. Writeup:{" "}
          <a href="https://nanlives.vercel.app" className="text-[var(--accent)] hover:underline">nanlives</a>.
        </p>
      </section>

      <footer className="max-w-7xl mx-auto px-6 mt-16 mb-8 pt-6 border-t border-[var(--border)] text-xs text-[var(--muted)]">
        source:{" "}
        <a href="https://github.com/noahjohnson0/lemon-squeezer" className="text-[var(--accent)] hover:underline">github.com/noahjohnson0/lemon-squeezer</a>
      </footer>
    </main>
  );
}
