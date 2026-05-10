"use client";
import { useEffect, useState } from "react";
import {
  loadRuns,
  loadInflight,
  type Run,
  type Inflight,
} from "@/lib/data";
import Hero from "@/components/Hero";
import StatsBar from "@/components/StatsBar";
import LiveRuns from "@/components/LiveRuns";
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

  const selectedRun = selectedRunId
    ? runs.find((r) => r.run_id === selectedRunId) ?? null
    : null;

  return (
    <main>
      <Hero runCount={runs.length} />
      <StatsBar runs={runs} />
      <LiveRuns data={inflight} />
      <Scatter3D runs={runs} onSelect={(id) => setSelectedRunId(id)} />
      <Leaderboard runs={runs} onSelectRun={(id) => setSelectedRunId(id)} />
      <HeatmapMatrix runs={runs} onSelectRun={(id) => setSelectedRunId(id)} />
      <HardwarePanel runs={runs} />
      <EvalDeepDive runs={runs} onSelectRun={(id) => setSelectedRunId(id)} />
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
            <span>live · auto-refresh</span>
          )}
        </div>
      </footer>
    </main>
  );
}
