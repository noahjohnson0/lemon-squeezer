"use client";
import { motion } from "framer-motion";
import { Run, unique } from "@/lib/data";

export default function StatsBar({ runs }: { runs: Run[] }) {
  const evals = unique(runs.map((r) => r.eval)).length;
  const models = unique(runs.map((r) => r.model)).length;
  const harnesses = unique(runs.map((r) => r.harness)).length;
  const totalWall = runs.reduce((s, r) => s + (r.wall_seconds || 0), 0);
  const totalTok = runs.reduce(
    (s, r) => s + (r.tokens_in || 0) + (r.tokens_out || 0),
    0
  );
  const best = runs.reduce((m, r) => (r.score_pct > m ? r.score_pct : m), 0);
  const totalPower = runs.reduce(
    (s, r) =>
      s +
      ((r.telemetry?.gpu_power_avg_w || 0) * (r.wall_seconds || 0)) / 3600,
    0
  );

  const stats = [
    { v: evals, label: "evals" },
    { v: models, label: "models" },
    { v: harnesses, label: "harnesses" },
    { v: `${best}%`, label: "best score" },
    { v: (totalWall / 60).toFixed(1), label: "compute (min)" },
    { v: (totalTok / 1e6).toFixed(2), label: "M tokens" },
    { v: totalPower.toFixed(1), label: "Wh" },
  ];

  return (
    <div className="max-w-7xl mx-auto px-6">
      <div className="grid grid-cols-2 md:grid-cols-7 gap-3">
        {stats.map((s, i) => (
          <motion.div
            key={s.label}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: i * 0.05 }}
            className="bg-[var(--panel)] border border-[var(--border)] rounded-xl px-4 py-3 hover:border-[var(--accent)]/30 transition-colors"
          >
            <div className="text-2xl font-bold text-[var(--accent)] tabular-nums">
              {s.v}
            </div>
            <div className="text-[10px] uppercase tracking-wider text-[var(--muted)] mt-0.5">
              {s.label}
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  );
}
