// Data layer: types + client-side loaders.
// All fetches are RELATIVE so they work the same way on localhost and on GitHub Pages
// (the basePath is automatically applied to assets in /public).

export type Telemetry = {
  samples?: number;
  gpu_util_avg?: number;
  gpu_util_peak?: number;
  gpu_mem_peak_mb?: number;
  gpu_mem_avg_mb?: number;
  gpu_temp_peak_c?: number;
  gpu_temp_avg_c?: number;
  gpu_power_avg_w?: number;
  gpu_power_peak_w?: number;
  gpu_fan_peak_pct?: number;
  host_load_peak?: number;
  // Mac-side fields (populated when host == m4max et al)
  host_cpu_avg_pct?: number;
  host_cpu_peak_pct?: number;
  host_mem_peak_pct?: number;
  ollama_rss_peak_mb?: number;
  ollama_rss_avg_mb?: number;
};

export type Run = {
  run_id: string;
  ts: string;
  eval: string;
  harness: string;
  model: string;
  tag: string;
  host?: string;          // "4070", "m4max", etc.
  exit_code: number;
  wall_seconds: number;
  tokens_in: number;
  tokens_out: number;
  tool_calls: number;
  score_pct: number;
  telemetry?: Telemetry;
};

export type InflightRun = {
  run_id: string;
  eval?: string;
  harness?: string;
  model?: string;
  tag?: string;
  active?: boolean;
  elapsed_s?: number;
  samples?: number;
  gpu_util_pct?: number | null;
  gpu_mem_used_mb?: number | null;
  gpu_temp_c?: number | null;
  gpu_power_w?: number | null;
  gpu_fan_pct?: number | null;
  last_stdout?: string;
};

export type QueuedRun = {
  harness?: string;
  eval?: string;
  model?: string;
  tag?: string;
  pid?: string;
  queued_for_s?: number;
};

export type Inflight = {
  generated_ts?: string;
  interval_s?: number;
  runs: InflightRun[];
  queued?: QueuedRun[];
};

export async function loadRuns(): Promise<Run[]> {
  const r = await fetch(`./runs.jsonl?t=${Date.now()}`, { cache: "no-store" });
  if (!r.ok) throw new Error(`runs.jsonl ${r.status}`);
  const text = await r.text();
  const runs: Run[] = [];
  for (const line of text.split("\n")) {
    const t = line.trim();
    if (!t) continue;
    try {
      const o = JSON.parse(t) as Run;
      o.score_pct =
        typeof o.score_pct === "string" ? parseInt(o.score_pct, 10) : o.score_pct;
      o.harness ||= "pi";
      o.host ||= "4070"; // legacy runs were all 4070
      runs.push(o);
    } catch {
      /* skip malformed line */
    }
  }
  runs.sort((a, b) => a.ts.localeCompare(b.ts));
  return runs;
}

export async function loadInflight(): Promise<Inflight | null> {
  try {
    const r = await fetch(`./inflight.json?t=${Date.now()}`, { cache: "no-store" });
    if (!r.ok) return null;
    return (await r.json()) as Inflight;
  } catch {
    return null;
  }
}

// Helpers --------------------------------------------------------

export function unique<T>(arr: T[]): T[] {
  return [...new Set(arr)].sort();
}

export function bestPer<K>(runs: Run[], keyFn: (r: Run) => K): Map<K, Run> {
  const m = new Map<K, Run>();
  for (const r of runs) {
    if (!Number.isFinite(r.score_pct)) continue;
    const k = keyFn(r);
    const cur = m.get(k);
    if (!cur || cur.score_pct < r.score_pct) m.set(k, r);
  }
  return m;
}

// Bayesian-shrunk score: pulls low-coverage rows toward the global mean.
//   shrunk = (n*avg + C*mu) / (n + C),  C=3 pseudo-evals
export function bayesianRank(rows: Array<{ avg: number; count: number }>, allMean: number, C = 3) {
  return rows.map((r) => ({
    ...r,
    shrunk: (r.count * r.avg + C * allMean) / (r.count + C),
  }));
}

export function scoreClass(s: number): "good" | "mid" | "bad" | "empty" {
  if (!Number.isFinite(s)) return "empty";
  return s >= 80 ? "good" : s >= 50 ? "mid" : "bad";
}

const PALETTE = [
  "#79c0ff",
  "#ffa657",
  "#d2a8ff",
  "#7ee787",
  "#f0883e",
  "#ff7b72",
  "#a5d6ff",
  "#ffd33d",
  "#56d4dd",
  "#ff9bdb",
  "#b48ead",
  "#a3be8c",
];
export function colorForModel(model: string, models: string[]): string {
  const i = models.indexOf(model);
  return PALETTE[((i % PALETTE.length) + PALETTE.length) % PALETTE.length];
}

export function fmtElapsed(s: number | undefined | null): string {
  if (s === null || s === undefined || !Number.isFinite(s)) return "–";
  if (s < 60) return `${Math.round(s)}s`;
  const m = Math.floor(s / 60);
  const r = Math.round(s % 60);
  return `${m}m ${r}s`;
}
