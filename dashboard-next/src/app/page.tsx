"use client";
import { useEffect, useMemo, useState } from "react";
import { loadRuns, type Run } from "@/lib/data";
import Hero from "@/components/Hero";
import Filters, { type FilterState } from "@/components/Filters";
import HarnessGap from "@/components/HarnessGap";
import Leaderboard from "@/components/Leaderboard";
import RunDrawer from "@/components/RunDrawer";

export default function Page() {
  const [runs, setRuns] = useState<Run[]>([]);
  const [selectedRunId, setSelectedRunId] = useState<string | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [filters, setFilters] = useState<FilterState>({ eval: "", harness: "", model: "", host: "" });

  useEffect(() => {
    let cancelled = false;
    async function refresh() {
      try {
        const data = await loadRuns();
        if (!cancelled) setRuns(data);
      } catch (e) {
        if (!cancelled) setLoadError(String(e));
      }
    }
    refresh();
    const id = setInterval(refresh, 10000);
    return () => {
      cancelled = true;
      clearInterval(id);
    };
  }, []);

  const filtered = useMemo(
    () =>
      runs.filter(
        (r) =>
          (!filters.eval || r.eval === filters.eval) &&
          (!filters.harness || r.harness === filters.harness) &&
          (!filters.model || r.model === filters.model) &&
          (!filters.host || (r.host ?? "4070") === filters.host)
      ),
    [runs, filters]
  );

  const selectedRun = selectedRunId
    ? runs.find((r) => r.run_id === selectedRunId) ?? null
    : null;

  return (
    <main>
      <Hero runCount={runs.length} />
      {/* Action: filter the board */}
      <Filters runs={runs} state={filters} onChange={setFilters} />
      {/* The one ranking: every contender, every venue */}
      <Leaderboard runs={filtered} onSelectRun={(id) => setSelectedRunId(id)} />
      {/* The headline insight: harness matters as much as model */}
      <HarnessGap runs={filtered} />
      <RunDrawer run={selectedRun} onClose={() => setSelectedRunId(null)} />

      <footer className="max-w-7xl mx-auto px-6 mt-16 mb-8 pt-6 border-t border-[var(--border)] text-xs text-[var(--muted)] flex flex-wrap gap-3 items-center justify-between">
        <div>
          source:{" "}
          <a
            href="https://github.com/noahjohnson0/lemon-squeezer"
            className="text-[var(--accent)] hover:underline"
          >
            github.com/noahjohnson0/lemon-squeezer
          </a>
        </div>
        <div>
          {loadError ? (
            <span className="text-[var(--bad)]">load: {loadError}</span>
          ) : (
            <span>auto-refresh · live status in the header</span>
          )}
        </div>
      </footer>
    </main>
  );
}
