"use client";
import { useEffect, useMemo, useState } from "react";
import type { Run } from "@/lib/data";
import { MODEL_META, VRAM_TIERS, detectVramTier } from "@/lib/modelMeta";

type Pick = { model: string; ciLo: number; ciHi: number; mean: number; n: number; cost: number; vram: number | null; tag?: string };

function perModel(runs: Run[]): Pick[] {
  // single-model cloud quality (venue-independent), CI lower bound so low-n can't win
  const g = new Map<string, { s: number[]; c: number[] }>();
  for (const r of runs) {
    if ((r.host ?? "4070") !== "openrouter") continue;
    if (r.harness !== "squeezer-cloud") continue; // clean single-model quality signal
    if (!Number.isFinite(r.score_pct)) continue;
    const e = g.get(r.model) ?? { s: [], c: [] };
    e.s.push(r.score_pct); e.c.push(r.cost_usd ?? 0); g.set(r.model, e);
  }
  const out: Pick[] = [];
  for (const [model, { s, c }] of g) {
    const n = s.length;
    const mean = s.reduce((a, b) => a + b, 0) / n;
    let half = 50;
    if (n >= 2) {
      const sd = Math.sqrt(s.reduce((a, b) => a + (b - mean) ** 2, 0) / (n - 1));
      half = 1.96 * sd / Math.sqrt(n);
    }
    out.push({
      model, mean, ciLo: Math.max(0, mean - half), ciHi: Math.min(100, mean + half), n,
      cost: c.reduce((a, b) => a + b, 0) / n,
      vram: MODEL_META[model]?.vramQ4GB ?? undefined as unknown as number | null,
      tag: MODEL_META[model]?.ollamaTag,
    });
  }
  return out.filter((p) => p.n >= 3).sort((a, b) => b.ciLo - a.ciLo);
}

function Tile({ kind, pick, tier }: { kind: "local" | "cloud"; pick?: Pick; tier?: number }) {
  const local = kind === "local";
  return (
    <div className="card flex-1 min-w-[260px] p-5">
      <div className="flex items-center gap-2 text-[10px] uppercase tracking-[0.2em] text-[var(--muted)]">
        <span>{local ? "Best fit for your VRAM" : "Best rented open-weight model"}</span>
        {local && tier ? <span className="chip">{tier} GB</span> : null}
      </div>
      {pick ? (
        <>
          <div className="mt-2 font-mono text-lg text-[var(--text)]">{pick.model}</div>
          <div className="mt-1 text-3xl font-bold gradient-text tabular-nums">{pick.mean.toFixed(0)}%</div>
          <div className="text-xs text-[var(--muted)] tabular-nums">
            95% CI {pick.ciLo.toFixed(0)}-{pick.ciHi.toFixed(0)} · n={pick.n}{local && pick.vram ? ` · ~${pick.vram} GB @ q4` : ""}
            {!local ? ` · $${pick.cost < 0.01 ? pick.cost.toFixed(5) : pick.cost.toFixed(3)}/task` : ""}
          </div>
          <div className="mt-3 text-xs">
            {local ? (
              pick.tag
                ? <code className="text-[var(--accent-2)]">ollama run {pick.tag}</code>
                : <span className="text-[var(--muted)]">pull the {pick.vram}-GB-class build from Ollama</span>
            ) : (
              <span className="text-[var(--muted)]">rent on OpenRouter at low cost per task, no local GPU</span>
            )}
          </div>
        </>
      ) : (
        <div className="mt-3 text-sm text-[var(--muted)]">
          {local ? "No measured model fits this VRAM yet." : "No cloud data yet."}
        </div>
      )}
    </div>
  );
}

export default function Recommender({ runs }: { runs: Run[] }) {
  const [tier, setTier] = useState(12);
  const [auto, setAuto] = useState<number | null>(null);
  useEffect(() => { const d = detectVramTier(); if (d) { setAuto(d); setTier(d); } }, []);

  const picks = useMemo(() => perModel(runs), [runs]);
  const bestCloud = picks[0];
  const bestLocal = useMemo(
    () => picks.find((p) => p.vram != null && p.vram <= tier),
    [picks, tier]
  );

  return (
    <section className="max-w-7xl mx-auto px-6 mt-6">
      <div className="flex items-baseline gap-3 mb-3 flex-wrap">
        <h2 className="text-xl font-semibold">What should you run?</h2>
        <span className="text-xs text-[var(--muted)]">
          the best open-weight coding agent for your hardware vs the cloud, by score on this benchmark. quality is venue-independent, so we measure it once in the cloud.
        </span>
        <label className="ml-auto text-xs text-[var(--muted)] flex items-center gap-2">
          your VRAM
          <select
            value={tier}
            onChange={(e) => setTier(Number(e.target.value))}
            className="bg-[var(--panel)] border border-[var(--border)] rounded px-2 py-1 text-xs font-mono"
          >
            {VRAM_TIERS.map((t) => <option key={t} value={t}>{t} GB</option>)}
          </select>
          {auto ? <span className="text-[var(--accent)]">detected ~{auto} GB</span> : null}
        </label>
      </div>
      <div className="flex flex-wrap gap-3">
        <Tile kind="local" pick={bestLocal} tier={tier} />
        <Tile kind="cloud" pick={bestCloud} />
      </div>
      <p className="text-[10px] text-[var(--muted)] mt-2">
        Local quality shown is the cloud (higher-precision) score; a local q4 build runs ~3-5 points lower in our tests. VRAM is an approximate q4 estimate.
      </p>
    </section>
  );
}
