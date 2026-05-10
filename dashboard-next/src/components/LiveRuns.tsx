"use client";
import { motion, AnimatePresence } from "framer-motion";
import { Inflight, fmtElapsed } from "@/lib/data";

export default function LiveRuns({ data }: { data: Inflight | null }) {
  if (!data) return null;
  const ageMs = data.generated_ts
    ? Date.now() - new Date(data.generated_ts).getTime()
    : Infinity;
  const stale = ageMs > 30000;
  const empty = !data.runs || data.runs.length === 0;
  if (stale && empty) return null;

  return (
    <motion.section
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4 }}
      className="max-w-7xl mx-auto px-6 mt-8"
    >
      <div className="bg-[var(--panel)] border-l-4 border-[var(--accent)] border-t border-r border-b border-[var(--border)] rounded-xl p-4 glow-y">
        <div className="flex items-center gap-3 mb-3">
          <motion.span
            className="w-2.5 h-2.5 rounded-full bg-[var(--good)]"
            animate={{ opacity: [1, 0.3, 1], scale: [1, 0.8, 1] }}
            transition={{ duration: 1.6, repeat: Infinity }}
            style={{ boxShadow: "0 0 8px var(--good)" }}
          />
          <h3 className="font-semibold">Running right now</h3>
          <span className="chip">{data.runs.length} active</span>
          {data.queued && data.queued.length > 0 && (
            <span className="chip">{data.queued.length} queued</span>
          )}
          <span className="ml-auto text-xs text-[var(--muted)]">
            updated {Math.round(ageMs / 1000)}s ago
          </span>
        </div>
        <div className="space-y-2">
          <AnimatePresence mode="popLayout">
            {data.runs.map((r) => (
              <motion.div
                key={r.run_id}
                layout
                initial={{ opacity: 0, x: -10 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: 10 }}
                className="flex items-center gap-3 py-2 border-t border-[var(--border)] first:border-t-0"
              >
                <div className="flex-1 flex items-center gap-2 flex-wrap">
                  <span className="font-mono text-sm font-semibold">{r.eval}</span>
                  <span className={`chip ${r.harness}`}>{r.harness}</span>
                  <span className="text-sm text-[var(--text)]/85">{r.model}</span>
                  {r.tag && <span className="chip">{r.tag}</span>}
                  <span className="text-xs text-[var(--muted)]">
                    {fmtElapsed(r.elapsed_s)} · {r.samples ?? 0} samples
                  </span>
                </div>
                <div className="flex items-center gap-3 font-mono text-xs">
                  {r.gpu_util_pct !== null && r.gpu_util_pct !== undefined && (
                    <div className="flex items-center gap-2" title="GPU utilisation">
                      <div className="w-16 h-1 bg-[var(--border)] rounded overflow-hidden">
                        <motion.div
                          className="h-full bg-[var(--accent)]"
                          initial={{ width: 0 }}
                          animate={{ width: `${Math.max(0, Math.min(100, r.gpu_util_pct))}%` }}
                          transition={{ duration: 0.5 }}
                        />
                      </div>
                      <span className="tabular-nums w-9 text-right">{Math.round(r.gpu_util_pct)}%</span>
                    </div>
                  )}
                  {r.gpu_temp_c !== null && r.gpu_temp_c !== undefined && (
                    <span
                      className="tabular-nums"
                      style={{
                        color:
                          r.gpu_temp_c > 80
                            ? "var(--bad)"
                            : r.gpu_temp_c > 70
                            ? "var(--mid)"
                            : "var(--text)",
                      }}
                      title="GPU temperature"
                    >
                      {Math.round(r.gpu_temp_c)}°C
                    </span>
                  )}
                  {r.gpu_power_w !== null && r.gpu_power_w !== undefined && (
                    <span className="tabular-nums" title="GPU power">
                      {Math.round(r.gpu_power_w)}W
                    </span>
                  )}
                  {r.gpu_mem_used_mb !== null && r.gpu_mem_used_mb !== undefined && (
                    <span className="tabular-nums" title="VRAM used">
                      {(r.gpu_mem_used_mb / 1024).toFixed(1)}GB
                    </span>
                  )}
                </div>
              </motion.div>
            ))}
          </AnimatePresence>
          {data.runs.length === 0 && (
            <p className="text-xs text-[var(--muted)] italic">
              watcher is up · no evals running
            </p>
          )}
        </div>
        {data.queued && data.queued.length > 0 && (
          <div className="mt-3 pt-3 border-t border-[var(--border)]">
            <div className="text-[10px] uppercase tracking-wider text-[var(--muted)] mb-2">
              Queued for GPU lock
            </div>
            <div className="space-y-1">
              {data.queued.map((q, i) => (
                <div key={`${q.pid}-${i}`} className="flex items-center gap-2 text-sm opacity-80">
                  <span className="text-[var(--muted)]">⏳</span>
                  <span className="font-mono font-semibold">{q.eval}</span>
                  <span className={`chip ${q.harness ?? ""}`}>{q.harness}</span>
                  <span>{q.model}</span>
                  {q.tag && <span className="chip">{q.tag}</span>}
                  <span className="ml-auto text-xs text-[var(--muted)] font-mono">
                    waiting {fmtElapsed(q.queued_for_s)}
                  </span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </motion.section>
  );
}
