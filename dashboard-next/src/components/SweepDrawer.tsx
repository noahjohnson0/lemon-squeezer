"use client";
import { motion, AnimatePresence } from "framer-motion";
import { useMemo, useState } from "react";
import { BenchData, Sweep, domainBreakdown, pctAcc, scoreClassForAcc } from "@/lib/bench";

type Filter = "all" | "hits" | "misses";

export default function SweepDrawer({
  sweep,
  data,
  onClose,
}: {
  sweep: Sweep | null;
  data: BenchData | null;
  onClose: () => void;
}) {
  const [filter, setFilter] = useState<Filter>("all");
  const [search, setSearch] = useState("");

  const qset = sweep && data ? data.qsets[sweep.qset] : null;
  const dom = useMemo(() => {
    if (!sweep || !qset) return null;
    return domainBreakdown(sweep, qset);
  }, [sweep, qset]);

  const filteredRows = useMemo(() => {
    if (!sweep) return [];
    const term = search.trim().toLowerCase();
    return sweep.per_q.filter((r) => {
      if (filter === "hits" && !r.hit) return false;
      if (filter === "misses" && r.hit) return false;
      if (term && !r.question.toLowerCase().includes(term) && !r.id.toLowerCase().includes(term)) return false;
      return true;
    });
  }, [sweep, filter, search]);

  return (
    <AnimatePresence>
      {sweep && (
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
            className="absolute right-0 top-0 bottom-0 w-full sm:w-[760px] bg-[var(--bg)] border-l border-[var(--border)] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            <button
              onClick={onClose}
              className="absolute top-4 right-4 text-[var(--muted)] hover:text-[var(--text)] text-2xl leading-none"
            >
              ×
            </button>
            <div className="p-6">
              <h2 className="text-xl font-semibold flex items-baseline gap-3 mb-1 flex-wrap">
                <span className="font-mono">{sweep.model}</span>
                <span className="text-sm text-[var(--muted)] font-normal">{sweep.qset}</span>
                {sweep.tag && <span className="chip">{sweep.tag}</span>}
              </h2>
              <div className="text-xs text-[var(--muted)] font-mono mb-4 break-all">{sweep.sweep_id}</div>

              <div className="bg-[var(--panel)] border border-[var(--border)] rounded-lg p-3 mb-4">
                <div className="flex items-center gap-2 flex-wrap mb-2">
                  <span className="chip">{sweep.harness}</span>
                  {sweep.host && <span className="chip">{sweep.host}</span>}
                  <span
                    className={`score-${scoreClassForAcc(sweep.accuracy)} px-3 py-1 rounded font-bold tabular-nums`}
                  >
                    {pctAcc(sweep.accuracy)}
                  </span>
                  <span className="text-xs text-[var(--muted)]">{sweep.hits}/{sweep.n} hits</span>
                </div>
                <div className="text-xs text-[var(--muted)] flex flex-wrap gap-x-3">
                  <span>μ {sweep.wall_seconds_mean?.toFixed(1)}s</span>
                  <span>·</span>
                  <span>Σ {sweep.wall_seconds_total?.toFixed(0)}s wall</span>
                  <span>·</span>
                  <span>{sweep.tokens_in_total?.toLocaleString()} tokens in</span>
                  <span>·</span>
                  <span>{sweep.tokens_out_total?.toLocaleString()} tokens out</span>
                  <span>·</span>
                  <span>{sweep.tool_calls_total ?? "-"} tool calls</span>
                </div>
                {sweep.corpora?.length > 0 && (
                  <div className="mt-3">
                    <div className="text-[10px] uppercase tracking-wider text-[var(--muted)] mb-1">corpora ({sweep.corpora.length})</div>
                    <div className="flex flex-wrap gap-1">
                      {sweep.corpora.map((c) => (
                        <span key={c} className="font-mono text-[10px] px-1.5 py-0.5 rounded bg-[var(--panel-2)] text-[var(--muted)]">
                          {c}
                        </span>
                      ))}
                    </div>
                  </div>
                )}
              </div>

              {dom && dom.size > 1 && (
                <>
                  <h3 className="text-sm font-semibold text-[var(--accent)] mb-2">
                    Per-domain breakdown
                  </h3>
                  <div className="bg-[var(--panel)] border border-[var(--border)] rounded-lg p-3 mb-4">
                    <table className="w-full text-xs">
                      <thead className="text-[10px] uppercase tracking-wider text-[var(--muted)]">
                        <tr>
                          <th className="text-left pb-2">domain</th>
                          <th className="text-right pb-2">hits</th>
                          <th className="text-right pb-2">n</th>
                          <th className="text-right pb-2">accuracy</th>
                        </tr>
                      </thead>
                      <tbody>
                        {[...dom.entries()]
                          .sort((a, b) => (b[1].hits / Math.max(b[1].n, 1)) - (a[1].hits / Math.max(a[1].n, 1)))
                          .map(([d, { hits, n }]) => {
                            const acc = n > 0 ? hits / n : 0;
                            return (
                              <tr key={d} className="border-t border-[var(--border)]">
                                <td className="py-1.5 font-mono">{d}</td>
                                <td className="py-1.5 text-right tabular-nums">{hits}</td>
                                <td className="py-1.5 text-right tabular-nums">{n}</td>
                                <td className="py-1.5 text-right">
                                  <span className={`score-${scoreClassForAcc(acc)} px-2 py-0.5 rounded text-xs font-bold tabular-nums`}>
                                    {pctAcc(acc)}
                                  </span>
                                </td>
                              </tr>
                            );
                          })}
                      </tbody>
                    </table>
                  </div>
                </>
              )}

              <h3 className="text-sm font-semibold text-[var(--accent)] mb-2 flex items-center gap-3 flex-wrap">
                <span>Per-question detail</span>
                <span className="text-xs font-normal text-[var(--muted)]">{filteredRows.length} of {sweep.per_q.length}</span>
              </h3>

              <div className="flex items-center gap-2 mb-3 flex-wrap">
                {(["all", "hits", "misses"] as Filter[]).map((f) => (
                  <button
                    key={f}
                    onClick={() => setFilter(f)}
                    className={`text-xs px-2 py-1 rounded border ${
                      filter === f
                        ? "border-[var(--accent)] text-[var(--accent)]"
                        : "border-[var(--border)] text-[var(--muted)] hover:text-[var(--text)]"
                    }`}
                  >
                    {f}
                  </button>
                ))}
                <input
                  type="search"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  placeholder="filter questions…"
                  className="bg-[var(--panel)] border border-[var(--border)] rounded px-2 py-1 text-xs font-mono flex-1 min-w-[160px]"
                />
              </div>

              <div className="space-y-2 mb-4">
                {filteredRows.map((r) => (
                  <PerQRow key={r.id} r={r} />
                ))}
              </div>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

function PerQRow({ r }: { r: { id: string; question: string; answer_value: string; model_answer: string; hit: boolean; matched_alias: string | null; wall_seconds: number; tokens_in: number; tokens_out: number; tool_calls: number } }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="bg-[var(--panel)] border border-[var(--border)] rounded-lg overflow-hidden">
      <button
        onClick={() => setOpen((o) => !o)}
        className="w-full px-3 py-2 flex items-start gap-3 text-left hover:bg-[var(--panel-2)]"
      >
        <span className={`flex-shrink-0 w-5 h-5 rounded-full flex items-center justify-center text-xs font-bold ${r.hit ? "bg-[var(--good)] text-black" : "bg-[var(--bad)] text-white"}`}>
          {r.hit ? "✓" : "✗"}
        </span>
        <div className="flex-1 min-w-0">
          <div className="flex items-baseline gap-2 flex-wrap">
            <span className="font-mono text-[11px] text-[var(--muted)]">{r.id}</span>
            <span className="text-xs text-[var(--text)] truncate">{r.question}</span>
          </div>
          {!open && (
            <div className="text-[11px] text-[var(--muted)] mt-0.5 truncate">
              gold: <span className="text-[var(--text)]">{r.answer_value}</span>
              {r.matched_alias && <span className="ml-2">· matched: <code>{r.matched_alias}</code></span>}
            </div>
          )}
        </div>
        <span className="text-[10px] text-[var(--muted)] flex-shrink-0 tabular-nums">
          {r.wall_seconds?.toFixed(0)}s · {r.tool_calls}t
        </span>
      </button>
      {open && (
        <div className="px-3 pb-3 text-xs space-y-2 border-t border-[var(--border)] pt-3">
          <div>
            <div className="text-[10px] uppercase tracking-wider text-[var(--muted)] mb-1">question</div>
            <div className="text-[var(--text)]">{r.question}</div>
          </div>
          <div>
            <div className="text-[10px] uppercase tracking-wider text-[var(--muted)] mb-1">gold answer</div>
            <div className="font-mono text-[var(--text)]">{r.answer_value}</div>
            {r.matched_alias && (
              <div className="text-[11px] text-[var(--muted)] mt-0.5">matched alias: <code>{r.matched_alias}</code></div>
            )}
          </div>
          <div>
            <div className="text-[10px] uppercase tracking-wider text-[var(--muted)] mb-1">model answer</div>
            <div className="text-[var(--text)] whitespace-pre-wrap font-sans bg-[var(--panel-2)] p-2 rounded text-[11px] leading-relaxed">
              {r.model_answer || <span className="text-[var(--muted)] italic">(empty)</span>}
            </div>
          </div>
          <div className="text-[10px] text-[var(--muted)] flex gap-3 flex-wrap">
            <span>tokens in: {r.tokens_in?.toLocaleString()}</span>
            <span>tokens out: {r.tokens_out?.toLocaleString()}</span>
            <span>tools: {r.tool_calls}</span>
            <span>wall: {r.wall_seconds?.toFixed(1)}s</span>
          </div>
        </div>
      )}
    </div>
  );
}
