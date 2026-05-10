"use client";
import { motion, AnimatePresence } from "framer-motion";
import { Run, bayesianRank, bestPer, scoreClass, unique } from "@/lib/data";

function ScoreCell({ s, runId, onClick }: { s: number; runId?: string; onClick?: (id: string) => void }) {
  const cls = scoreClass(s);
  return (
    <button
      onClick={() => runId && onClick?.(runId)}
      className={`score-${cls} px-2 py-1 rounded text-xs font-bold tabular-nums min-w-[36px] text-center transition-transform hover:scale-110 disabled:cursor-default`}
      disabled={!runId}
    >
      {Number.isFinite(s) ? s : "–"}
    </button>
  );
}

export default function Leaderboard({
  runs,
  onSelectRun,
}: {
  runs: Run[];
  onSelectRun: (id: string) => void;
}) {
  const evals = unique(runs.map((r) => r.eval));
  const harnesses = unique(runs.map((r) => r.harness));
  const models = unique(runs.map((r) => r.model));
  const hosts = unique(runs.map((r) => r.host ?? "4070"));
  // Key includes host now: same model on different hosts is now separate rows.
  const best = bestPer(runs, (r) => `${r.eval}|${r.harness}|${r.model}|${r.host ?? "4070"}`);
  const allCells = [...best.values()];
  const allMean =
    allCells.length > 0
      ? allCells.reduce((s, r) => s + r.score_pct, 0) / allCells.length
      : 50;

  type Row = {
    host: string;
    harness: string;
    model: string;
    cells: (Run | undefined)[];
    avg: number;
    count: number;
    shrunk: number;
  };
  const rows: Row[] = [];
  for (const host of hosts) {
    for (const h of harnesses) {
      for (const m of models) {
        const cells = evals.map((e) => best.get(`${e}|${h}|${m}|${host}`));
        const present = cells.filter(Boolean) as Run[];
        if (present.length === 0) continue;
        const avg = present.reduce((s, r) => s + r.score_pct, 0) / present.length;
        rows.push({
          host,
          harness: h,
          model: m,
          cells,
          avg: Math.round(avg),
          count: present.length,
          shrunk: 0,
        });
      }
    }
  }
  const ranked = bayesianRank(rows, allMean) as Row[];
  ranked.sort(
    (a, b) =>
      b.shrunk - a.shrunk ||
      b.count - a.count ||
      b.avg - a.avg ||
      a.harness.localeCompare(b.harness) ||
      a.model.localeCompare(b.model) ||
      a.host.localeCompare(b.host)
  );

  return (
    <section className="max-w-7xl mx-auto px-6 mt-12">
      <div className="flex items-baseline gap-3 mb-2">
        <h2 className="text-xl font-semibold">Leaderboard</h2>
        <span className="chip">{ranked.length} configurations</span>
      </div>
      <p className="text-[var(--muted)] text-sm max-w-3xl mb-4">
        Best score per (harness × model × eval). The <strong>rank</strong> column is a
        Bayesian-shrunk score: <code className="text-xs">(n·avg + C·μ) / (n + C)</code>{" "}
        with C=3, so a 1/{evals.length} row of 100% won't outrank a {evals.length}/{evals.length}{" "}
        row of 95%. Click any cell for the run's score breakdown.
      </p>

      <div className="bg-[var(--panel)] border border-[var(--border)] rounded-xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-xs">
            <thead className="text-[10px] uppercase tracking-wider text-[var(--muted)] border-b border-[var(--border)]">
              <tr>
                <th className="px-3 py-3 text-left sticky left-0 bg-[var(--panel)] z-10">#</th>
                <th className="px-3 py-3 text-left sticky left-[44px] bg-[var(--panel)] z-10">host</th>
                <th className="px-3 py-3 text-left sticky left-[110px] bg-[var(--panel)] z-10">harness</th>
                <th className="px-3 py-3 text-left sticky left-[206px] bg-[var(--panel)] z-10 shadow-[1px_0_0_var(--border)]">
                  model
                </th>
                {evals.map((e) => (
                  <th key={e} className="px-2 py-3 text-center font-mono">
                    {e}
                  </th>
                ))}
                <th className="px-3 py-3 text-right">avg</th>
                <th className="px-3 py-3 text-right">rank</th>
                <th className="px-3 py-3 text-right">cov</th>
              </tr>
            </thead>
            <tbody>
              <AnimatePresence>
                {ranked.map((row, idx) => {
                  const rank = idx + 1;
                  const medal =
                    rank === 1 ? "🥇" : rank === 2 ? "🥈" : rank === 3 ? "🥉" : `${rank}`;
                  const covPct = (100 * row.count) / evals.length;
                  const covColor =
                    covPct >= 80 ? "text-[var(--text)]" : covPct >= 40 ? "text-[var(--mid)]" : "text-[var(--muted)]";
                  return (
                    <motion.tr
                      layout
                      key={`${row.host}|${row.harness}|${row.model}`}
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      transition={{ duration: 0.3, delay: idx * 0.02 }}
                      className="border-b border-[var(--border)] hover:bg-[var(--panel-2)] group"
                    >
                      <td className="px-3 py-2 sticky left-0 bg-[var(--panel)] group-hover:bg-[var(--panel-2)] text-[var(--muted)] font-bold text-sm">
                        {medal}
                      </td>
                      <td className="px-3 py-2 sticky left-[44px] bg-[var(--panel)] group-hover:bg-[var(--panel-2)]">
                        <span className="chip" title="hardware host">{row.host}</span>
                      </td>
                      <td className="px-3 py-2 sticky left-[110px] bg-[var(--panel)] group-hover:bg-[var(--panel-2)]">
                        <span className={`chip ${row.harness}`}>{row.harness}</span>
                      </td>
                      <td className="px-3 py-2 sticky left-[206px] bg-[var(--panel)] group-hover:bg-[var(--panel-2)] shadow-[1px_0_0_var(--border)] font-mono whitespace-nowrap">
                        {row.model}
                      </td>
                      {row.cells.map((c, i) => (
                        <td key={i} className="px-1 py-2 text-center">
                          {c ? (
                            <ScoreCell s={c.score_pct} runId={c.run_id} onClick={onSelectRun} />
                          ) : (
                            <span className="score-empty px-2 py-1 rounded text-xs">–</span>
                          )}
                        </td>
                      ))}
                      <td className="px-3 py-2 text-right">
                        <ScoreCell s={row.avg} />
                      </td>
                      <td className="px-3 py-2 text-right">
                        <ScoreCell s={Math.round(row.shrunk)} />
                      </td>
                      <td className={`px-3 py-2 text-right font-mono tabular-nums ${covColor}`}>
                        {row.count}/{evals.length}
                      </td>
                    </motion.tr>
                  );
                })}
              </AnimatePresence>
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
}
