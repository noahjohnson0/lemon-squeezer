"use client";
import { useEffect, useMemo, useState } from "react";
import {
  loadRuns,
  loadInflight,
  type Run,
  type Inflight,
} from "@/lib/data";
import Hero from "@/components/Hero";
import Headline from "@/components/Headline";
import StatsBar from "@/components/StatsBar";
import LiveRuns from "@/components/LiveRuns";
import Filters, { type FilterState } from "@/components/Filters";
import HarnessGap from "@/components/HarnessGap";
import Leaderboard from "@/components/Leaderboard";
import Scatter3D from "@/components/Scatter3D";
import HeatmapMatrix from "@/components/HeatmapMatrix";
import HardwarePanel from "@/components/HardwarePanel";
import EvalDeepDive from "@/components/EvalDeepDive";
import RunDrawer from "@/components/RunDrawer";

export default function Page() {
  const [runs, setRuns] = useState<Run[]>([]);
  const [inflight, setInflight] = useState<Inflight | null>(null);
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

  useEffect(() => {
    let cancelled = false;
    async function refresh() {
      const data = await loadInflight();
      if (!cancelled) setInflight(data);
    }
    refresh();
    const id = setInterval(refresh, 2000);
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
      {/* The actual answer - what to run on your GPU. */}
      <Headline runs={runs} />
      <LiveRuns data={inflight} />
      {/* Action: filter the rest of the page */}
      <Filters runs={runs} state={filters} onChange={setFilters} />
      {/* The supporting evidence, in order of importance */}
      <Leaderboard runs={filtered} onSelectRun={(id) => setSelectedRunId(id)} />
      <HarnessGap runs={filtered} />
      <HeatmapMatrix runs={filtered} onSelectRun={(id) => setSelectedRunId(id)} />
      <EvalDeepDive runs={filtered} onSelectRun={(id) => setSelectedRunId(id)} />
      {/* Auxiliary - efficiency / hardware / 3D for fun */}
      <HardwarePanel runs={filtered} />
      <Scatter3D runs={filtered} onSelect={(id) => setSelectedRunId(id)} />
      <StatsBar runs={runs} />
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
