"use client";
import { Sweep, comparisonGroups, pctAcc, scoreClassForAcc } from "@/lib/bench";

export default function SweepComparison({
  sweeps,
  onSelect,
}: {
  sweeps: Sweep[];
  onSelect: (sweepId: string) => void;
}) {
  const groups = comparisonGroups(sweeps);
  if (groups.size === 0) return null;

  return (
    <section className="max-w-7xl mx-auto px-6 mt-12">
      <div className="flex items-baseline gap-3 mb-2">
        <h2 className="text-xl font-semibold">Tag comparisons</h2>
        <span className="chip">{groups.size} ablation{groups.size === 1 ? "" : "s"}</span>
      </div>
      <p className="text-[var(--muted)] text-sm max-w-3xl mb-4">
        Same (qset × model) with different tags - these are direct ablations. The classic case is
        wikipedia-only vs all-corpora on <code>gridown-50</code>.
      </p>

      <div className="grid gap-4 md:grid-cols-2">
        {[...groups.entries()].map(([key, arr]) => {
          const [qset, model] = key.split("|");
          // Sort by tag for stable ordering
          const sorted = [...arr].sort((a, b) => (a.tag ?? "").localeCompare(b.tag ?? ""));
          const bestAcc = Math.max(...sorted.map((s) => s.accuracy));
          return (
            <div
              key={key}
              className="bg-[var(--panel)] border border-[var(--border)] rounded-xl p-4"
            >
              <div className="flex items-baseline gap-2 mb-3 flex-wrap">
                <span className="chip">{qset}</span>
                <span className="font-mono text-sm">{model}</span>
              </div>
              <table className="w-full text-xs">
                <thead className="text-[10px] uppercase tracking-wider text-[var(--muted)]">
                  <tr>
                    <th className="text-left pb-2">tag</th>
                    <th className="text-right pb-2">acc</th>
                    <th className="text-right pb-2">hits</th>
                    <th className="text-right pb-2">corpora</th>
                    <th className="text-right pb-2">μ wall</th>
                  </tr>
                </thead>
                <tbody>
                  {sorted.map((s) => {
                    const best = s.accuracy === bestAcc;
                    return (
                      <tr
                        key={s.sweep_id}
                        onClick={() => onSelect(s.sweep_id)}
                        className="border-t border-[var(--border)] cursor-pointer hover:bg-[var(--panel-2)]"
                      >
                        <td className="py-1.5">
                          <span className="chip">{s.tag ?? "-"}</span>
                          {best && <span className="ml-1 text-[10px] text-[var(--good)]">★</span>}
                        </td>
                        <td className="py-1.5 text-right">
                          <span className={`score-${scoreClassForAcc(s.accuracy)} px-2 py-0.5 rounded text-xs font-bold tabular-nums`}>
                            {pctAcc(s.accuracy)}
                          </span>
                        </td>
                        <td className="py-1.5 text-right tabular-nums text-[var(--muted)]">
                          {s.hits}/{s.n}
                        </td>
                        <td className="py-1.5 text-right tabular-nums text-[var(--muted)]">
                          {s.corpora.length}
                        </td>
                        <td className="py-1.5 text-right tabular-nums text-[var(--muted)]">
                          {s.wall_seconds_mean?.toFixed(1)}s
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          );
        })}
      </div>
    </section>
  );
}
