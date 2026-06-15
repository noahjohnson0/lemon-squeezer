"use client";
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Run, meanPer, scoreClass, unique } from "@/lib/data";
import { EVAL_BLURBS } from "@/lib/blurbs";

export default function EvalDeepDive({
  runs,
  onSelectRun,
}: {
  runs: Run[];
  onSelectRun: (id: string) => void;
}) {
  const evals = unique(runs.map((r) => r.eval));
  const [openSet, setOpenSet] = useState<Set<string>>(() => new Set(evals.slice(0, 1)));
  const toggle = (e: string) =>
    setOpenSet((prev) => {
      const next = new Set(prev);
      if (next.has(e)) next.delete(e);
      else next.add(e);
      return next;
    });

  return (
    <section className="max-w-7xl mx-auto px-6 mt-12">
      <div className="flex items-baseline gap-3 mb-2">
        <h2 className="text-xl font-semibold">Per-eval deep dive</h2>
        <span className="chip">{evals.length} evals</span>
      </div>
      <p className="text-[var(--muted)] text-sm max-w-3xl mb-4">
        Each eval is a self-contained directory with a <code>prompt.md</code>, optional{" "}
        <code>setup.sh</code>, and a <code>rubric.sh</code> that runs the produced code
        and scores it. Click a row in the expanded view to see its score breakdown.
      </p>
      <div className="space-y-2">
        {evals.map((e) => {
          const blurb = EVAL_BLURBS[e] || {
            summary: "(no blurb yet)",
            discriminates: "",
          };
          const evalRuns = runs.filter((r) => r.eval === e);
          const best = meanPer(evalRuns, (r) => `${r.harness}|${r.model}|${r.tag}`);
          const sorted = [...best.values()].sort((a, b) => b.score_pct - a.score_pct);
          const isOpen = openSet.has(e);
          return (
            <div
              key={e}
              className="bg-[var(--panel)] border border-[var(--border)] rounded-xl overflow-hidden"
            >
              <button
                onClick={() => toggle(e)}
                className="w-full text-left px-4 py-3 hover:bg-[var(--panel-2)] flex items-center gap-3"
              >
                <motion.span
                  animate={{ rotate: isOpen ? 90 : 0 }}
                  className="text-[var(--muted)] inline-block"
                >
                  ▶
                </motion.span>
                <strong className="font-mono">{e}</strong>
                <span className="text-[var(--muted)] text-xs">
                  {evalRuns.length} runs · top mean {sorted[0]?.score_pct ?? "-"}%
                </span>
                <span className="ml-auto text-[var(--muted)] text-xs hidden md:block">
                  {blurb.summary}
                </span>
              </button>
              <AnimatePresence initial={false}>
                {isOpen && (
                  <motion.div
                    initial={{ height: 0, opacity: 0 }}
                    animate={{ height: "auto", opacity: 1 }}
                    exit={{ height: 0, opacity: 0 }}
                    transition={{ duration: 0.25 }}
                    className="overflow-hidden border-t border-[var(--border)]"
                  >
                    <div className="grid md:grid-cols-2 gap-4 p-4">
                      <div>
                        <div className="text-[10px] uppercase tracking-wider text-[var(--muted)] mb-1">
                          What the agent is asked to do
                        </div>
                        <p className="text-sm mb-3 leading-relaxed">{blurb.summary}</p>
                        <div className="text-[10px] uppercase tracking-wider text-[var(--muted)] mb-1">
                          What this discriminates
                        </div>
                        <p className="text-sm text-[var(--muted)] leading-relaxed">
                          {blurb.discriminates}
                        </p>
                      </div>
                      <div className="overflow-x-auto">
                        <table className="w-full text-xs">
                          <thead className="text-[10px] uppercase tracking-wider text-[var(--muted)]">
                            <tr>
                              <th className="text-left pb-2">harness</th>
                              <th className="text-left pb-2">model</th>
                              <th className="text-left pb-2">tag</th>
                              <th className="text-right pb-2">score</th>
                              <th className="text-right pb-2">wall</th>
                              <th className="text-right pb-2">tok</th>
                            </tr>
                          </thead>
                          <tbody>
                            {sorted.map((r) => (
                              <tr
                                key={r.run_id}
                                className="border-t border-[var(--border)] hover:bg-[var(--panel-2)] cursor-pointer"
                                onClick={() => onSelectRun(r.run_id)}
                              >
                                <td className="py-1.5">
                                  <span className={`chip ${r.harness}`}>{r.harness}</span>
                                </td>
                                <td className="py-1.5 font-mono text-[11px]">{r.model}</td>
                                <td className="py-1.5">
                                  <span className="chip">{r.tag}</span>
                                </td>
                                <td className="py-1.5 text-right">
                                  <span
                                    className={`score-${scoreClass(
                                      r.score_pct
                                    )} px-2 py-0.5 rounded font-bold`}
                                  >
                                    {r.score_pct}
                                  </span>
                                </td>
                                <td className="py-1.5 text-right text-[var(--muted)] tabular-nums">
                                  {r.wall_seconds}s
                                </td>
                                <td className="py-1.5 text-right text-[var(--muted)] tabular-nums">
                                  {(r.tokens_in + r.tokens_out).toLocaleString()}
                                </td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          );
        })}
      </div>
    </section>
  );
}
