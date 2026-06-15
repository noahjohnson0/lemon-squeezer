"use client";
import { motion } from "framer-motion";
import { Run, meanPer, scoreClass, unique } from "@/lib/data";

/**
 * The single most important block on the page: "what's the answer".
 *
 * Computes:
 *  - the best (harness × model) combo by Bayesian-shrunk avg
 *  - how many evals it has hit ≥80% on
 *  - the harness gap (best harness mean minus worst harness mean)
 */
export default function Headline({ runs }: { runs: Run[] }) {
  if (runs.length === 0) return null;

  const evals = unique(runs.map((r) => r.eval));
  const harnesses = unique(runs.map((r) => r.harness));
  const models = unique(runs.map((r) => r.model));
  const hosts = unique(runs.map((r) => r.host ?? "4070"));
  // Same combo on different hardware = different combo, so include host in the key.
  // meanPer = mean score per cell across trials (not best-of, which overstates).
  const best = meanPer(runs, (r) => `${r.eval}|${r.harness}|${r.model}|${r.host ?? "4070"}`);

  const allCells = [...best.values()];
  const allMean =
    allCells.reduce((s, r) => s + r.score_pct, 0) / Math.max(1, allCells.length);
  const C = 3;
  type Combo = {
    host: string;
    harness: string;
    model: string;
    avg: number;
    count: number;
    shrunk: number;
    bestEval?: { eval: string; score: number };
    weakEval?: { eval: string; score: number };
  };
  const combos: Combo[] = [];
  for (const host of hosts) {
    for (const h of harnesses) {
      for (const m of models) {
        const cells = evals.map((e) => best.get(`${e}|${h}|${m}|${host}`));
        const present = cells.filter(Boolean) as Run[];
        if (present.length < 2) continue;
        const avg = present.reduce((s, r) => s + r.score_pct, 0) / present.length;
        const shrunk = (present.length * avg + C * allMean) / (present.length + C);
        const sorted = [...present].sort((a, b) => b.score_pct - a.score_pct);
        combos.push({
          host,
          harness: h,
          model: m,
          avg,
          count: present.length,
          shrunk,
          bestEval: { eval: sorted[0].eval, score: sorted[0].score_pct },
          weakEval: { eval: sorted.at(-1)!.eval, score: sorted.at(-1)!.score_pct },
        });
      }
    }
  }
  combos.sort((a, b) => b.shrunk - a.shrunk);
  const champ = combos[0];

  // Harness gap: best harness avg minus worst harness avg, on intersect of (eval, model)s
  const harnessAvg = harnesses.map((h) => {
    const xs = [...best.values()].filter((r) => r.harness === h);
    return {
      h,
      avg:
        xs.length > 0
          ? xs.reduce((s, r) => s + r.score_pct, 0) / xs.length
          : 0,
      n: xs.length,
    };
  });
  harnessAvg.sort((a, b) => b.avg - a.avg);
  const topH = harnessAvg[0];
  const botH = harnessAvg.at(-1);
  const gap = topH && botH ? topH.avg - botH.avg : 0;

  // Eval coverage at >=80%
  const cellsBy = (e: string) => [...best.values()].filter((r) => r.eval === e);
  const solvedAt80 = evals.filter((e) =>
    cellsBy(e).some((r) => r.score_pct >= 80)
  ).length;
  const solvedAt100 = evals.filter((e) =>
    cellsBy(e).some((r) => r.score_pct === 100)
  ).length;

  // Build a "best on each eval" series for a tiny inline sparkline-ish row
  const evalChamps = evals.map((e) => {
    const xs = cellsBy(e).sort((a, b) => b.score_pct - a.score_pct);
    return { eval: e, run: xs[0] ?? null };
  });

  return (
    <section className="max-w-7xl mx-auto px-6 mt-6">
      <div className="bg-gradient-to-br from-[var(--panel)] to-[var(--panel-2)] border border-[var(--border)] rounded-2xl p-6 md:p-8 glow-y">
        {/* Recommendation header */}
        <div className="flex items-center gap-2 mb-3">
          <span className="text-[10px] uppercase tracking-[0.2em] text-[var(--accent)] font-bold">
            Recommendation
          </span>
          <span className="text-[10px] uppercase tracking-wider text-[var(--muted)]">
            the best-scoring setup in this benchmark
          </span>
        </div>

        <div className="grid md:grid-cols-2 gap-6 items-center">
          {/* Champion */}
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
          >
            <div className="text-sm text-[var(--muted)] mb-1">Best combo overall</div>
            {champ ? (
              <>
                <div className="text-3xl md:text-4xl font-bold leading-tight">
                  <span className="font-mono text-[var(--accent)]">
                    {champ.model}
                  </span>
                </div>
                <div className="text-xl mt-1 text-[var(--text)]/85 flex items-center gap-2 flex-wrap">
                  via{" "}
                  <span className={`chip ${champ.harness} text-base`}>
                    {champ.harness}
                  </span>
                  on{" "}
                  <span className="chip text-base" title="hardware host">
                    {champ.host}
                  </span>
                </div>
                <div className="text-sm text-[var(--muted)] mt-3 leading-relaxed">
                  <span title="mean score pulled toward the overall mean when a combo has few evals, so a small lucky sample can't top the table">
                    Rank-adjusted score
                  </span>{" "}
                  <span className="text-[var(--text)] font-bold">
                    {champ.shrunk.toFixed(0)}%
                  </span>{" "}
                  across {champ.count} evals · raw mean {champ.avg.toFixed(0)}%
                </div>
                {champ.bestEval && (
                  <div className="text-xs text-[var(--muted)] mt-2">
                    Best on{" "}
                    <span className="font-mono text-[var(--good)]">
                      {champ.bestEval.eval}
                    </span>{" "}
                    @ {champ.bestEval.score}%
                    {champ.weakEval && champ.weakEval.eval !== champ.bestEval.eval && (
                      <>
                        {" "}
                        · weakest on{" "}
                        <span className="font-mono text-[var(--bad)]">
                          {champ.weakEval.eval}
                        </span>{" "}
                        @ {champ.weakEval.score}%
                      </>
                    )}
                  </div>
                )}
              </>
            ) : (
              <div className="text-[var(--muted)]">no data yet</div>
            )}
          </motion.div>

          {/* Harness insight */}
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.1 }}
            className="md:border-l md:border-[var(--border)] md:pl-6"
          >
            <div className="text-sm text-[var(--muted)] mb-1">
              The harness gap
            </div>
            {topH && botH ? (
              <>
                <div className="text-3xl md:text-4xl font-bold leading-tight">
                  <span className="text-[var(--accent)]">+{gap.toFixed(0)}</span>{" "}
                  <span className="text-base text-[var(--muted)] font-normal">pts</span>
                </div>
                <div className="text-sm mt-1 text-[var(--text)]/85">
                  <span className={`chip ${topH.h}`}>{topH.h}</span> beats{" "}
                  <span className={`chip ${botH.h}`}>{botH.h}</span> by{" "}
                  <span className="text-[var(--text)] font-bold">
                    {gap.toFixed(0)}
                  </span>{" "}
                  pts on average
                </div>
                <div className="text-sm text-[var(--muted)] mt-3 leading-relaxed">
                  {topH.h}: {topH.avg.toFixed(0)}% avg ({topH.n} cells) ·{" "}
                  {botH.h}: {botH.avg.toFixed(0)}% avg ({botH.n} cells)
                </div>
                <div className="text-xs text-[var(--muted)] mt-2">
                  Same models, same evals - just changing how the harness shapes
                  the loop is worth more than swapping which 14B you run.
                </div>
              </>
            ) : (
              <div className="text-[var(--muted)]">need 2+ harnesses to compare</div>
            )}
          </motion.div>
        </div>

        {/* Eval coverage rail */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.6, delay: 0.25 }}
          className="mt-8 pt-6 border-t border-[var(--border)]"
        >
          <div className="flex items-baseline justify-between mb-3">
            <div>
              <div className="text-3xl font-bold tabular-nums text-[var(--accent)]">
                {solvedAt100}/{evals.length}
              </div>
              <div className="text-[10px] uppercase tracking-wider text-[var(--muted)] mt-0.5">
                evals where SOME combo hits 100%
              </div>
            </div>
            <div className="text-sm text-[var(--muted)]">
              <span className="text-[var(--good)] font-bold">{solvedAt80}</span> ≥ 80%{" "}
              · <span className="text-[var(--bad)] font-bold">{evals.length - solvedAt80}</span>{" "}
              still &lt; 80%
            </div>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-5 lg:grid-cols-7 gap-1">
            {evalChamps
              .sort((a, b) => (b.run?.score_pct ?? -1) - (a.run?.score_pct ?? -1))
              .map(({ eval: e, run }) => {
                const cls = run ? scoreClass(run.score_pct) : "empty";
                return (
                  <div
                    key={e}
                    className="flex items-center gap-1.5"
                    title={
                      run
                        ? `${e}: ${run.score_pct}% via ${run.harness} × ${run.model}`
                        : `${e}: no runs yet`
                    }
                  >
                    <span
                      className={`score-${cls} px-1.5 rounded text-[10px] font-bold tabular-nums w-10 text-center`}
                    >
                      {run ? run.score_pct : "-"}
                    </span>
                    <span className="font-mono text-[10px] text-[var(--muted)] truncate">
                      {e}
                    </span>
                  </div>
                );
              })}
          </div>
        </motion.div>
      </div>
    </section>
  );
}
