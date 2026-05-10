"use client";
import { motion } from "framer-motion";
import { Run, bestPer, scoreClass, unique } from "@/lib/data";

export default function HeatmapMatrix({
  runs,
  onSelectRun,
}: {
  runs: Run[];
  onSelectRun: (id: string) => void;
}) {
  const evals = unique(runs.map((r) => r.eval));
  const harnesses = unique(runs.map((r) => r.harness));
  const models = unique(runs.map((r) => r.model));
  const best = bestPer(runs, (r) => `${r.eval}|${r.harness}|${r.model}`);

  // 1 row per (harness, model) that has at least one run.
  const rows: { harness: string; model: string }[] = [];
  for (const h of harnesses) {
    for (const m of models) {
      const has = evals.some((e) => best.has(`${e}|${h}|${m}`));
      if (has) rows.push({ harness: h, model: m });
    }
  }

  return (
    <section className="max-w-7xl mx-auto px-6 mt-12">
      <div className="flex items-baseline gap-3 mb-2">
        <h2 className="text-xl font-semibold">Heatmap matrix</h2>
        <span className="chip">
          {rows.length}×{evals.length} cells
        </span>
      </div>
      <p className="text-[var(--muted)] text-sm max-w-3xl mb-4">
        Every (harness × model) row, every eval column. Cell color encodes the best
        score that combination has reached on the eval. Click for the run.
      </p>
      <div className="bg-[var(--panel)] border border-[var(--border)] rounded-xl p-3 overflow-x-auto">
        <table className="w-full text-xs border-separate border-spacing-1">
          <thead>
            <tr>
              <th className="text-left text-[10px] uppercase tracking-wider text-[var(--muted)] sticky left-0 bg-[var(--panel)] z-10 px-2 py-2">
                harness · model
              </th>
              {evals.map((e) => (
                <th
                  key={e}
                  className="text-[10px] font-mono text-[var(--muted)] px-1 py-2 align-bottom"
                  style={{ writingMode: "vertical-rl", transform: "rotate(180deg)" }}
                >
                  {e}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map(({ harness, model }, ri) => (
              <motion.tr
                key={`${harness}|${model}`}
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ duration: 0.3, delay: ri * 0.02 }}
              >
                <td className="sticky left-0 bg-[var(--panel)] z-10 whitespace-nowrap px-2 py-1">
                  <span className={`chip ${harness} mr-1`}>{harness}</span>
                  <span className="font-mono text-[11px]">{model}</span>
                </td>
                {evals.map((e) => {
                  const r = best.get(`${e}|${harness}|${model}`);
                  if (!r) {
                    return (
                      <td key={e} className="p-0">
                        <div className="w-9 h-9 bg-[var(--panel-2)] rounded-sm" />
                      </td>
                    );
                  }
                  const cls = scoreClass(r.score_pct);
                  // intensity by score
                  const intensity = Math.max(0.18, Math.min(0.85, r.score_pct / 100));
                  const bg =
                    cls === "good"
                      ? `rgba(63,185,80,${intensity})`
                      : cls === "mid"
                      ? `rgba(210,153,34,${intensity})`
                      : `rgba(248,81,73,${intensity})`;
                  return (
                    <td key={e} className="p-0">
                      <button
                        onClick={() => onSelectRun(r.run_id)}
                        title={`${e} · ${harness} · ${model}\nscore: ${r.score_pct}%\nwall: ${r.wall_seconds}s\ntag: ${r.tag}`}
                        className="w-9 h-9 rounded-sm font-bold text-[10px] tabular-nums hover:scale-110 transition-transform"
                        style={{ background: bg, color: "white" }}
                      >
                        {r.score_pct}
                      </button>
                    </td>
                  );
                })}
              </motion.tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
