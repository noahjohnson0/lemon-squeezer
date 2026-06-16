"use client";
import { useEffect, useMemo, useState } from "react";
import { loadRuns, loadInflight, type Run, type Inflight } from "@/lib/data";
import Headline from "@/components/Headline";
import LiveRuns from "@/components/LiveRuns";
import HardwarePanel from "@/components/HardwarePanel";
import Scatter3D from "@/components/Scatter3D";
import StatsBar from "@/components/StatsBar";
import RunDrawer from "@/components/RunDrawer";

// The hardware side of the benchmark: VRAM fit, speed, watts, live GPU telemetry.
// Capability ranking (including these local models) lives on the unified board at /.
export default function LocalPage() {
  const [runs, setRuns] = useState<Run[]>([]);
  const [inflight, setInflight] = useState<Inflight | null>(null);
  const [selectedRunId, setSelectedRunId] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    const refresh = () =>
      loadRuns("../runs.jsonl")
        .then((d) => !cancelled && setRuns(d))
        .catch((e) => !cancelled && setErr(String(e)));
    refresh();
    const id = setInterval(refresh, 10000);
    return () => { cancelled = true; clearInterval(id); };
  }, []);

  useEffect(() => {
    let cancelled = false;
    const refresh = () => loadInflight("../inflight.json").then((d) => !cancelled && setInflight(d));
    refresh();
    const id = setInterval(refresh, 2000);
    return () => { cancelled = true; clearInterval(id); };
  }, []);

  // Local venues only - cloud (openrouter) runs carry no GPU telemetry.
  const localRuns = useMemo(() => runs.filter((r) => (r.host ?? "4070") !== "openrouter"), [runs]);
  const selectedRun = selectedRunId ? runs.find((r) => r.run_id === selectedRunId) ?? null : null;

  return (
    <main>
      <section className="max-w-7xl mx-auto px-6 pt-10 pb-4">
        <div className="flex items-center gap-3 mb-2">
          <span className="text-[10px] uppercase tracking-[0.25em] text-[var(--muted)]">
            local venue · consumer GPUs
          </span>
        </div>
        <h1 className="text-3xl md:text-5xl font-bold tracking-tight gradient-text leading-[1.04]">
          What can your own GPU actually run?
        </h1>
        <p className="text-[var(--muted)] text-base mt-3 max-w-3xl leading-relaxed">
          The hardware side of the benchmark: which models fit in VRAM on a consumer card, how fast
          they run, and what they cost in watts and wall-time. The capability ranking - including
          these local models as their own tier - lives on the{" "}
          <a href="../" className="text-[var(--accent)] hover:underline">main leaderboard</a>.
        </p>
      </section>

      <Headline runs={localRuns} />
      <LiveRuns data={inflight} />
      <HardwarePanel runs={localRuns} />
      <Scatter3D runs={localRuns} onSelect={(id) => setSelectedRunId(id)} />
      <StatsBar runs={localRuns} />
      <RunDrawer run={selectedRun} onClose={() => setSelectedRunId(null)} />

      <footer className="max-w-7xl mx-auto px-6 mt-16 mb-8 pt-6 border-t border-[var(--border)] text-xs text-[var(--muted)] flex flex-wrap gap-3 items-center justify-between">
        <div>
          source:{" "}
          <a href="https://github.com/noahjohnson0/lemon-squeezer" className="text-[var(--accent)] hover:underline">
            github.com/noahjohnson0/lemon-squeezer
          </a>
        </div>
        <div>{err ? <span className="text-[var(--bad)]">load: {err}</span> : <span>auto-refresh · live status in the header</span>}</div>
      </footer>
    </main>
  );
}
