"use client";
import { motion, AnimatePresence } from "framer-motion";
import { useEffect, useState } from "react";
import { Run, scoreClass } from "@/lib/data";
import { modelCardUrl } from "@/lib/modelMeta";

type ScoreCheck = { name: string; pass: 0 | 1 | number; weight: number; note?: string };
type Score = { checks: ScoreCheck[]; gained: number; total: number; score_pct: number };

// All breakdowns are bundled into one deployed file (runs/ itself is not shipped).
// Fetch once, cached; try root-relative then parent (for sub-routes like /cloud).
let _scoresPromise: Promise<Record<string, Score>> | null = null;
function loadScores(): Promise<Record<string, Score>> {
  if (_scoresPromise) return _scoresPromise;
  _scoresPromise = (async () => {
    for (const rel of ["./scores.json", "../scores.json"]) {
      try {
        const r = await fetch(rel, { cache: "force-cache" });
        if (r.ok) return (await r.json()) as Record<string, Score>;
      } catch { /* try next */ }
    }
    return {};
  })();
  return _scoresPromise;
}

export default function RunDrawer({
  run,
  onClose,
}: {
  run: Run | null;
  onClose: () => void;
}) {
  // undefined = loading, null = not found, Score = loaded
  const [score, setScore] = useState<Score | null | undefined>(undefined);
  useEffect(() => {
    setScore(undefined);
    if (!run) return;
    let live = true;
    loadScores().then((m) => { if (live) setScore(m[run.run_id] ?? null); });
    return () => { live = false; };
  }, [run]);

  return (
    <AnimatePresence>
      {run && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 bg-black/60 z-50"
          onClick={onClose}
        >
          <motion.div
            initial={{ x: "100%" }}
            animate={{ x: 0 }}
            exit={{ x: "100%" }}
            transition={{ type: "spring", damping: 22, stiffness: 200 }}
            className="absolute right-0 top-0 bottom-0 w-full sm:w-[640px] bg-[var(--bg)] border-l border-[var(--border)] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            <button
              onClick={onClose}
              className="absolute top-4 right-4 text-[var(--muted)] hover:text-[var(--text)] text-2xl leading-none"
            >
              ×
            </button>
            <div className="p-6">
              <h2 className="text-xl font-semibold flex items-baseline gap-3 mb-1">
                <span className="font-mono">{run.eval}</span>
                <span className="text-sm text-[var(--muted)] font-normal">{run.model}</span>
              </h2>
              <div className="text-xs text-[var(--muted)] font-mono mb-1 break-all">{run.run_id}</div>
              {modelCardUrl(run.model) && (
                <a href={modelCardUrl(run.model)!} target="_blank" rel="noopener noreferrer"
                   className="text-xs text-[var(--accent)] hover:underline mb-4 inline-block">
                  {run.model} model card ↗
                </a>
              )}

              <div className="bg-[var(--panel)] border border-[var(--border)] rounded-lg p-3 mb-4">
                <div className="flex items-center gap-2 flex-wrap mb-2">
                  <span className={`chip ${run.harness}`}>{run.harness}</span>
                  <span className="chip">{run.tag}</span>
                  {run.host && <span className="chip" title="hardware host">{run.host}</span>}
                  <span
                    className={`score-${scoreClass(run.score_pct)} px-3 py-1 rounded font-bold tabular-nums`}
                  >
                    {run.score_pct}%
                  </span>
                </div>
                <div className="text-xs text-[var(--muted)] flex flex-wrap gap-x-3">
                  <span>{run.wall_seconds}s</span>
                  <span>·</span>
                  <span>{run.tokens_in.toLocaleString()} in</span>
                  <span>·</span>
                  <span>{run.tokens_out.toLocaleString()} out</span>
                  <span>·</span>
                  <span>{run.tool_calls} tools</span>
                  <span>·</span>
                  <span>exit {run.exit_code}</span>
                </div>
              </div>

              <h3 className="text-sm font-semibold text-[var(--accent)] mb-2">
                Score breakdown
              </h3>
              {score ? (
                <table className="w-full text-xs mb-4">
                  <thead className="text-[10px] uppercase tracking-wider text-[var(--muted)]">
                    <tr>
                      <th className="text-left pb-2 w-6"></th>
                      <th className="text-left pb-2">check</th>
                      <th className="text-right pb-2">w</th>
                      <th className="text-left pb-2 pl-3">note</th>
                    </tr>
                  </thead>
                  <tbody>
                    {score.checks.map((c) => (
                      <tr key={c.name} className="border-t border-[var(--border)]">
                        <td className="py-1.5">{c.pass === 1 ? "✓" : "✗"}</td>
                        <td className="py-1.5 font-mono">{c.name}</td>
                        <td className="py-1.5 text-right text-[var(--muted)]">{c.weight}</td>
                        <td className="py-1.5 pl-3 text-[var(--muted)] text-[11px] break-words max-w-[280px]">
                          {c.note || ""}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : score === undefined ? (
                <p className="text-[var(--muted)] text-sm">loading…</p>
              ) : (
                <p className="text-[var(--muted)] text-sm">
                  Per-check breakdown not bundled for this run (older run, or rerun{" "}
                  <code className="text-[11px]">bin/build-scores</code>).
                </p>
              )}

              {run.telemetry && (
                <>
                  <h3 className="text-sm font-semibold text-[var(--accent)] mb-2 mt-4">
                    Hardware (this run)
                  </h3>
                  <div className="bg-[var(--panel)] border border-[var(--border)] rounded-lg p-3 text-xs grid grid-cols-2 gap-2">
                    <div>
                      <span className="text-[var(--muted)]">samples:</span>{" "}
                      {run.telemetry.samples ?? "?"}
                    </div>
                    <div>
                      <span className="text-[var(--muted)]">avg temp:</span>{" "}
                      {run.telemetry.gpu_temp_avg_c?.toFixed(1) ?? "?"}°C
                    </div>
                    <div>
                      <span className="text-[var(--muted)]">peak temp:</span>{" "}
                      {run.telemetry.gpu_temp_peak_c?.toFixed(1) ?? "?"}°C
                    </div>
                    <div>
                      <span className="text-[var(--muted)]">peak VRAM:</span>{" "}
                      {((run.telemetry.gpu_mem_peak_mb ?? 0) / 1024).toFixed(1)} GB
                    </div>
                    <div>
                      <span className="text-[var(--muted)]">avg power:</span>{" "}
                      {run.telemetry.gpu_power_avg_w?.toFixed(1) ?? "?"} W
                    </div>
                    <div>
                      <span className="text-[var(--muted)]">peak power:</span>{" "}
                      {run.telemetry.gpu_power_peak_w?.toFixed(1) ?? "?"} W
                    </div>
                  </div>
                </>
              )}
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
