"use client";
import { motion } from "framer-motion";
import { Run, meanPer, scoreClass, unique } from "@/lib/data";

const HARNESS_COLOR: Record<string, string> = {
  pi: "#ffa657",
  aider: "#79c0ff",
  squeezer: "#d2a8ff",
  "squeezer-tdd": "#b48ead",
  "squeezer-verify": "#a3be8c",
  "squeezer-critique": "#ff7b72",
  "squeezer-architect": "#56d4dd",
  "squeezer-ensemble": "#ffd33d",
};

export default function HarnessGap({ runs }: { runs: Run[] }) {
  const evals = unique(runs.map((r) => r.eval));
  const harnesses = unique(runs.map((r) => r.harness));
  // Mean score per (eval, harness), averaged across all (model, tag) and trials.
  const best = meanPer(runs, (r) => `${r.eval}|${r.harness}`);

  // Sort harnesses by overall avg score so the strongest sits at top legend.
  const harnessAvg = harnesses
    .map((h) => {
      const scores = evals
        .map((e) => best.get(`${e}|${h}`)?.score_pct)
        .filter((x): x is number => Number.isFinite(x ?? NaN));
      return {
        h,
        avg: scores.length > 0 ? scores.reduce((s, x) => s + x, 0) / scores.length : 0,
      };
    })
    .sort((a, b) => b.avg - a.avg);

  const sortedHarnesses = harnessAvg.map((x) => x.h);

  return (
    <section className="max-w-7xl mx-auto px-6 mt-12">
      <div className="flex items-baseline gap-3 mb-2">
        <h2 className="text-xl font-semibold">The harness gap</h2>
        <span className="chip">{harnesses.length} harnesses</span>
      </div>
      <p className="text-[var(--muted)] text-sm max-w-3xl mb-4">
        Mean score per harness on each eval (averaged across models, tags, and trials).
        The spread on a single eval is how much the harness choice alone is worth.
      </p>
      <div className="bg-[var(--panel)] border border-[var(--border)] rounded-xl p-4">
        {/* Legend */}
        <div className="flex flex-wrap gap-3 mb-4 text-xs">
          {sortedHarnesses.map((h) => (
            <div key={h} className="flex items-center gap-1.5">
              <span
                className="inline-block w-2.5 h-2.5 rounded-full"
                style={{
                  background: HARNESS_COLOR[h] ?? "#888",
                  boxShadow: `0 0 6px ${HARNESS_COLOR[h] ?? "#888"}80`,
                }}
              />
              <span className="font-mono">{h}</span>
              <span className="text-[var(--muted)]">
                avg {harnessAvg.find((x) => x.h === h)!.avg.toFixed(0)}
              </span>
            </div>
          ))}
        </div>
        <div className="space-y-2">
          {evals.map((e, i) => (
            <motion.div
              key={e}
              initial={{ opacity: 0, x: -8 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.3, delay: i * 0.02 }}
              className="grid grid-cols-[160px_1fr_auto] items-center gap-3 py-1"
            >
              <div className="font-mono text-xs text-[var(--text)]/85">{e}</div>
              <div className="relative h-8">
                {sortedHarnesses.map((h, hi) => {
                  const r = best.get(`${e}|${h}`);
                  if (!r) return null;
                  const color = HARNESS_COLOR[h] ?? "#888";
                  return (
                    <motion.div
                      key={h}
                      initial={{ width: 0 }}
                      animate={{ width: `${r.score_pct}%` }}
                      transition={{ duration: 0.6, delay: 0.05 * hi, ease: "easeOut" }}
                      className="absolute left-0 rounded h-1.5 origin-left"
                      style={{
                        background: color,
                        top: `${4 + hi * 4}px`,
                        boxShadow: `0 0 6px ${color}60`,
                      }}
                      title={`${h}: ${r.score_pct}% (${r.model})`}
                    />
                  );
                })}
              </div>
              <div className="flex gap-1.5 text-[10px] tabular-nums font-mono">
                {sortedHarnesses.map((h) => {
                  const r = best.get(`${e}|${h}`);
                  if (!r) return null;
                  const cls = scoreClass(r.score_pct);
                  return (
                    <span key={h} className={`score-${cls} px-1.5 rounded`}>
                      {r.score_pct}
                    </span>
                  );
                })}
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
