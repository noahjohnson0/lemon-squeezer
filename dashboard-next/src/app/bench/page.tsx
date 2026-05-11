"use client";
import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { loadBenchData, BenchData, Sweep } from "@/lib/bench";
import SweepsTable, { SweepsTableSort } from "@/components/SweepsTable";
import SweepDrawer from "@/components/SweepDrawer";
import SweepComparison from "@/components/SweepComparison";

export default function BenchPage() {
  const [data, setData] = useState<BenchData | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [qsetFilter, setQsetFilter] = useState<string>("");
  const [modelFilter, setModelFilter] = useState<string>("");
  const [sort, setSort] = useState<SweepsTableSort>({ key: "ts", dir: "desc" });
  const [selectedId, setSelectedId] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    loadBenchData()
      .then((d) => { if (!cancelled) setData(d); })
      .catch((e) => { if (!cancelled) setErr(String(e)); });
    return () => { cancelled = true; };
  }, []);

  const allSweeps = data?.sweeps ?? [];
  const qsetOptions = useMemo(() => Array.from(new Set(allSweeps.map((s) => s.qset))).sort(), [allSweeps]);
  const modelOptions = useMemo(() => Array.from(new Set(allSweeps.map((s) => s.model))).sort(), [allSweeps]);

  const filtered = useMemo(
    () => allSweeps.filter((s) =>
      (!qsetFilter || s.qset === qsetFilter) &&
      (!modelFilter || s.model === modelFilter)
    ),
    [allSweeps, qsetFilter, modelFilter]
  );

  const selected: Sweep | null = selectedId
    ? allSweeps.find((s) => s.sweep_id === selectedId) ?? null
    : null;

  // Aggregate stats for the header
  const stats = useMemo(() => {
    const totalQ = filtered.reduce((sum, s) => sum + (s.n ?? 0), 0);
    const totalHits = filtered.reduce((sum, s) => sum + (s.hits ?? 0), 0);
    const totalWall = filtered.reduce((sum, s) => sum + (s.wall_seconds_total ?? 0), 0);
    const totalTokensIn = filtered.reduce((sum, s) => sum + (s.tokens_in_total ?? 0), 0);
    const totalTokensOut = filtered.reduce((sum, s) => sum + (s.tokens_out_total ?? 0), 0);
    return { totalQ, totalHits, totalWall, totalTokensIn, totalTokensOut };
  }, [filtered]);

  return (
    <main>
      <section className="max-w-7xl mx-auto px-6 pt-10 pb-4">
        <div className="flex items-center justify-between gap-3 mb-2 flex-wrap">
          <div className="flex items-center gap-3">
            <Link href="/" className="text-[var(--muted)] hover:text-[var(--accent)] text-xs">← dashboard</Link>
            <span className="text-3xl">📚</span>
            <span className="text-[10px] uppercase tracking-[0.2em] text-[var(--muted)]">
              rag-bench sweeps
            </span>
          </div>
          <div className="flex items-baseline gap-2 text-[var(--muted)] text-xs uppercase tracking-wider">
            <span className="text-[var(--accent)] font-bold tabular-nums text-base normal-case tracking-normal">
              {allSweeps.length}
            </span>
            <span>sweeps</span>
          </div>
        </div>
        <h1 className="text-3xl md:text-4xl font-bold tracking-tight gradient-text leading-[1.05]">
          Benchmarks
        </h1>
        <p className="text-[var(--muted)] italic text-base mt-2 max-w-3xl">
          Retrieval-augmented Q&amp;A sweeps from <code className="text-xs">bin/rag-bench</code>. Each
          row is one model run across a question set, with hit/miss recorded per question. Click a
          row for per-Q detail; click any tag-comparison card to drill into an ablation.
        </p>
      </section>

      <section className="max-w-7xl mx-auto px-6 mt-2">
        <div className="bg-[var(--panel)] border border-[var(--border)] rounded-xl px-4 py-3 flex flex-wrap items-center gap-4 text-xs">
          <div className="flex items-center gap-2">
            <span className="text-[10px] uppercase tracking-wider text-[var(--muted)]">qset</span>
            <select
              value={qsetFilter}
              onChange={(e) => setQsetFilter(e.target.value)}
              className="bg-[var(--panel)] border border-[var(--border)] rounded px-2 py-1 text-xs font-mono"
            >
              <option value="">all</option>
              {qsetOptions.map((q) => <option key={q} value={q}>{q}</option>)}
            </select>
          </div>
          <div className="flex items-center gap-2">
            <span className="text-[10px] uppercase tracking-wider text-[var(--muted)]">model</span>
            <select
              value={modelFilter}
              onChange={(e) => setModelFilter(e.target.value)}
              className="bg-[var(--panel)] border border-[var(--border)] rounded px-2 py-1 text-xs font-mono"
            >
              <option value="">all</option>
              {modelOptions.map((m) => <option key={m} value={m}>{m}</option>)}
            </select>
          </div>
          {(qsetFilter || modelFilter) && (
            <button
              onClick={() => { setQsetFilter(""); setModelFilter(""); }}
              className="text-xs text-[var(--accent)] hover:underline ml-auto"
            >
              clear
            </button>
          )}
          <div className="ml-auto flex gap-4 text-[var(--muted)] tabular-nums">
            <span>{filtered.length} sweeps</span>
            <span>·</span>
            <span>{stats.totalHits.toLocaleString()}/{stats.totalQ.toLocaleString()} hits</span>
            <span>·</span>
            <span>{stats.totalTokensIn.toLocaleString()} tok in</span>
            <span>·</span>
            <span>{Math.round(stats.totalWall).toLocaleString()}s wall</span>
          </div>
        </div>
      </section>

      <section className="max-w-7xl mx-auto px-6 mt-6">
        <div className="flex items-baseline gap-3 mb-2">
          <h2 className="text-xl font-semibold">Sweeps</h2>
          <span className="chip">{filtered.length}</span>
        </div>
        <p className="text-[var(--muted)] text-sm max-w-3xl mb-4">
          Newest first by default. Click any column header to sort. Click a row for the
          per-question hit/miss table and (for <code>gridown-50</code>) per-domain accuracy.
        </p>
        <SweepsTable
          sweeps={filtered}
          sort={sort}
          onSortChange={setSort}
          onSelect={setSelectedId}
          selectedId={selectedId}
        />
      </section>

      <SweepComparison sweeps={filtered} onSelect={setSelectedId} />

      <SweepDrawer
        sweep={selected}
        data={data}
        onClose={() => setSelectedId(null)}
      />

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
          {err ? (
            <span className="text-[var(--bad)]">load: {err}</span>
          ) : data ? (
            <span>data: {new Date(data.generated_at).toLocaleString()}</span>
          ) : (
            <span>loading…</span>
          )}
        </div>
      </footer>
    </main>
  );
}
