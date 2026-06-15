"use client";
import { motion, AnimatePresence } from "framer-motion";
import { useMemo } from "react";
import { Run, scoreClass } from "@/lib/data";

export type ArmRef = { model: string; harness: string };

// Side sheet that summarizes an ARM (model x harness): headline stats plus its
// per-eval scores sorted weakest-first, so you immediately see where this arm
// actually loses points - not one arbitrary run it aced. Click an eval to drill
// into a representative run for it.
export default function ArmDrawer({
  arm,
  runs,
  onClose,
  onPickEval,
}: {
  arm: ArmRef | null;
  runs: Run[];
  onClose: () => void;
  onPickEval: (model: string, harness: string, ev: string) => void;
}) {
  const data = useMemo(() => {
    if (!arm) return null;
    const mine = runs.filter((r) => r.model === arm.model && r.harness === arm.harness);
    const byEval = new Map<string, number[]>();
    let cost = 0, costN = 0, wall = 0, wallN = 0;
    for (const r of mine) {
      if (Number.isFinite(r.score_pct))
        (byEval.get(r.eval) ?? byEval.set(r.eval, []).get(r.eval)!).push(r.score_pct);
      if (r.cost_usd != null) { cost += r.cost_usd; costN++; }
      if (r.wall_seconds != null) { wall += r.wall_seconds; wallN++; }
    }
    const evals = [...byEval.entries()]
      .map(([e, xs]) => ({ eval: e, mean: xs.reduce((s, x) => s + x, 0) / xs.length, n: xs.length }))
      .sort((a, b) => a.mean - b.mean);
    const evalMeans = evals.map((e) => e.mean);
    const mean = evalMeans.length ? evalMeans.reduce((s, x) => s + x, 0) / evalMeans.length : 0;
    let ciLo: number | null = null, ciHi: number | null = null;
    if (evalMeans.length >= 2) {
      const v = evalMeans.reduce((s, x) => s + (x - mean) ** 2, 0) / (evalMeans.length - 1);
      const half = (1.96 * Math.sqrt(v)) / Math.sqrt(evalMeans.length);
      ciLo = Math.max(0, mean - half); ciHi = Math.min(100, mean + half);
    }
    return {
      evals, mean, ciLo, ciHi, n: mine.length,
      meanCost: costN ? cost / costN : 0,
      meanWall: wallN ? wall / wallN : 0,
      perfect: evals.filter((e) => e.mean >= 99.5).length,
    };
  }, [arm, runs]);

  const fmtCost = (c: number) => (c >= 0.01 ? `$${c.toFixed(3)}` : `$${c.toFixed(5)}`);

  return (
    <AnimatePresence>
      {arm && data && (
        <motion.div
          initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
          className="fixed inset-0 bg-black/60 z-50" onClick={onClose}
        >
          <motion.div
            initial={{ x: "100%" }} animate={{ x: 0 }} exit={{ x: "100%" }}
            transition={{ type: "spring", damping: 22, stiffness: 200 }}
            className="absolute right-0 top-0 bottom-0 w-full sm:w-[560px] bg-[var(--bg)] border-l border-[var(--border)] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            <button onClick={onClose} className="absolute top-4 right-4 text-[var(--muted)] hover:text-[var(--text)] text-2xl leading-none">×</button>
            <div className="p-6">
              <div className="text-[10px] uppercase tracking-[0.2em] text-[var(--muted)] mb-1">arm summary</div>
              <h2 className="text-xl font-semibold flex items-baseline gap-3 mb-1">
                <span className="font-mono text-[var(--accent)]">{arm.model}</span>
                <span className={`chip ${arm.harness}`}>{arm.harness}</span>
              </h2>

              <div className="bg-[var(--panel)] border border-[var(--border)] rounded-lg p-3 my-4 grid grid-cols-2 gap-y-2 text-sm">
                <div><span className="text-[var(--muted)] text-xs">mean score</span><div className="text-2xl font-bold gradient-text tabular-nums">{data.mean.toFixed(1)}%</div></div>
                <div><span className="text-[var(--muted)] text-xs">95% CI (over evals)</span><div className="text-lg tabular-nums">{data.ciLo !== null ? `${data.ciLo.toFixed(0)}-${data.ciHi!.toFixed(0)}` : "insufficient"}</div></div>
                <div><span className="text-[var(--muted)] text-xs">cost / task</span><div className="tabular-nums">{fmtCost(data.meanCost)}</div></div>
                <div><span className="text-[var(--muted)] text-xs">latency · runs</span><div className="tabular-nums">{data.meanWall.toFixed(0)}s · n={data.n}</div></div>
              </div>

              <h3 className="text-sm font-semibold text-[var(--accent)] mb-1">Per-eval scores</h3>
              <p className="text-xs text-[var(--muted)] mb-3">
                {data.perfect}/{data.evals.length} evals solved perfectly. Sorted weakest first - this is where the arm
                actually loses points. Click an eval to open a run.
              </p>
              <div className="space-y-1">
                {data.evals.map((e) => (
                  <button
                    key={e.eval}
                    onClick={() => onPickEval(arm.model, arm.harness, e.eval)}
                    className="w-full flex items-center gap-3 px-2 py-1.5 rounded hover:bg-[var(--panel-2)] text-left"
                  >
                    <span className={`score-${scoreClass(e.mean)} px-2 py-0.5 rounded text-xs font-bold tabular-nums w-12 text-center`}>
                      {e.mean.toFixed(0)}
                    </span>
                    <span className="font-mono text-xs flex-1 truncate">{e.eval}</span>
                    <span className="text-[10px] text-[var(--faint)]">n={e.n}</span>
                  </button>
                ))}
              </div>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
