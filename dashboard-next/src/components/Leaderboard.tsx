"use client";
import { motion, AnimatePresence } from "framer-motion";
import { Run, bayesianRank, meanPer, scoreClass, unique, isMainSuite, fmtCost } from "@/lib/data";
import { harnessBlurb } from "@/lib/blurbs";

function ScoreCell({ s, runId, onClick }: { s: number; runId?: string; onClick?: (id: string) => void }) {
  const cls = scoreClass(s);
  return (
    <button
      onClick={() => runId && onClick?.(runId)}
      className={`score-${cls} px-2 py-1 rounded text-xs font-bold tabular-nums min-w-[36px] text-center transition-transform hover:scale-110 disabled:cursor-default`}
      disabled={!runId}
    >
      {Number.isFinite(s) ? s : "-"}
    </button>
  );
}

// Venue at a glance: a cloud for OpenRouter, a GPU chip for a local box. The host
// name is on hover, so this also doubles as the "what's a host" explainer.
function HostGlyph({ host }: { host: string }) {
  const cloud = host === "openrouter";
  return (
    <span
      title={cloud ? "cloud · OpenRouter" : `local GPU · ${host}`}
      className="inline-flex items-center text-[var(--muted)]"
    >
      {cloud ? (
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-label="cloud">
          <path d="M17.5 19a4.5 4.5 0 0 0 .5-8.97A6 6 0 0 0 6.34 9.5 4 4 0 0 0 7 17.5z" />
        </svg>
      ) : (
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-label="local GPU">
          <rect x="4" y="7" width="16" height="10" rx="1" />
          <path d="M8 7V5M12 7V5M16 7V5M8 19v-2M12 19v-2M16 19v-2" />
        </svg>
      )}
    </span>
  );
}

export default function Leaderboard({
  runs: allRuns,
  onSelectRun,
}: {
  runs: Run[];
  onSelectRun: (id: string) => void;
}) {
  // One board, every venue (local GPUs + cloud). Drop environment-only evals
  // (port-scanner) and the separate hard-tier/showcase suites so the ranking is
  // apples-to-apples - the hard tier lives in its own section on /cloud. Also drop
  // the qa/librarian harnesses: those are RAG/QA tasks, not coding (see /bench).
  const NON_CODING_HARNESSES = new Set(["qa", "librarian"]);
  const runs = allRuns.filter((r) => isMainSuite(r) && !NON_CODING_HARNESSES.has(r.harness));
  // Hide thin rows (stub runs / small ablations) - below this many evals a row is
  // statistically meaningless and just clutters the board.
  const COVERAGE_FLOOR = 12;
  const evals = unique(runs.map((r) => r.eval));
  const harnesses = unique(runs.map((r) => r.harness));
  const models = unique(runs.map((r) => r.model));
  const hosts = unique(runs.map((r) => r.host ?? "4070"));
  // Key includes host now: same model on different hosts is now separate rows.
  // meanPer = mean score per cell across trials (not best-of, which overstates).
  const best = meanPer(runs, (r) => `${r.eval}|${r.harness}|${r.model}|${r.host ?? "4070"}`);

  // Mean cost-per-task per arm (cloud runs carry cost_usd; local runs don't).
  const costAcc = new Map<string, { sum: number; n: number }>();
  for (const r of runs) {
    if (typeof r.cost_usd !== "number") continue;
    const k = `${r.host ?? "4070"}|${r.harness}|${r.model}`;
    const c = costAcc.get(k) ?? { sum: 0, n: 0 };
    c.sum += r.cost_usd;
    c.n += 1;
    costAcc.set(k, c);
  }
  const armCost = (host: string, h: string, m: string): number | null => {
    const c = costAcc.get(`${host}|${h}|${m}`);
    return c && c.n ? c.sum / c.n : null;
  };
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
    cost: number | null;
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
          cost: armCost(host, h, m),
        });
      }
    }
  }
  const rankedAll = bayesianRank(rows, allMean) as Row[];
  const ranked = rankedAll.filter((r) => r.count >= COVERAGE_FLOOR);
  const hiddenCount = rankedAll.length - ranked.length;
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
        <span className="chip">{ranked.length} contenders</span>
      </div>
      <p className="text-[var(--muted)] text-sm max-w-3xl mb-2">
        Every contender, every venue ranked together by capability. Mean score per
        (harness × model × eval), averaged over trials; the <strong>rank</strong> column is
        coverage-adjusted, so a 1/{evals.length} row of 100% can&apos;t outrank a{" "}
        {evals.length}/{evals.length} row of 95%. <strong>$/task</strong> is mean cloud cost
        (blank for local). The separate hard tier is on the{" "}
        <a href="./cloud/" className="text-[var(--accent)] hover:underline">cloud page</a>.
        Click any cell for its breakdown.
      </p>
      <p className="text-[var(--muted)] text-xs max-w-3xl mb-4">
        <strong>harness</strong> = the agent scaffold around the model (single-pass,
        plan-then-build, write-tests-and-self-correct, ...). It moves scores as much as the
        model does - hover any harness chip for what it does. The venue glyph is{" "}
        <span className="inline-flex items-center align-middle"><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M17.5 19a4.5 4.5 0 0 0 .5-8.97A6 6 0 0 0 6.34 9.5 4 4 0 0 0 7 17.5z"/></svg></span>{" "}
        cloud,{" "}
        <span className="inline-flex items-center align-middle"><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="4" y="7" width="16" height="10" rx="1"/><path d="M8 7V5M12 7V5M16 7V5M8 19v-2M12 19v-2M16 19v-2"/></svg></span>{" "}
        local GPU.
      </p>
      {hiddenCount > 0 && (
        <p className="text-[var(--faint)] text-xs mb-4">
          {hiddenCount} thin row{hiddenCount === 1 ? "" : "s"} (under {COVERAGE_FLOOR}/{evals.length} evals) hidden.
        </p>
      )}

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
                <th className="px-3 py-3 text-right">$/task</th>
              </tr>
            </thead>
            <tbody>
              <AnimatePresence>
                {ranked.map((row, idx) => {
                  const rank = idx + 1;
                  const medal = `#${rank}`;
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
                        <HostGlyph host={row.host} />
                      </td>
                      <td className="px-3 py-2 sticky left-[110px] bg-[var(--panel)] group-hover:bg-[var(--panel-2)]">
                        <span className={`chip ${row.harness} cursor-help`} title={harnessBlurb(row.harness)}>{row.harness}</span>
                      </td>
                      <td className="px-3 py-2 sticky left-[206px] bg-[var(--panel)] group-hover:bg-[var(--panel-2)] shadow-[1px_0_0_var(--border)] font-mono whitespace-nowrap">
                        {row.model}
                      </td>
                      {row.cells.map((c, i) => (
                        <td key={i} className="px-1 py-2 text-center">
                          {c ? (
                            <ScoreCell s={c.score_pct} runId={c.run_id} onClick={onSelectRun} />
                          ) : (
                            <span className="score-empty px-2 py-1 rounded text-xs">-</span>
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
                      <td className="px-3 py-2 text-right font-mono tabular-nums text-[var(--muted)]" title="mean cloud cost per task (blank for local runs)">
                        {row.cost !== null ? fmtCost(row.cost) : <span className="text-[var(--faint)]">-</span>}
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
