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
  cost_usd?: number;       // cloud (OpenRouter) runs only
  mix?: {                  // present when the run is a multi-model pipeline
    pipeline: string;
    primary: string;
    critic?: string | null;
    judge?: string | null;
    architect?: string | null;
    rounds?: number;
  };
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

// `rel` lets sub-routes reach the site-root runs.jsonl: "./runs.jsonl" from the
// "/" page, "../runs.jsonl" from "/cloud/" (trailingSlash is on).
export async function loadRuns(rel = "./runs.jsonl"): Promise<Run[]> {
  const r = await fetch(`${rel}?t=${Date.now()}`, { cache: "no-store" });
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
  // Stamp the newest run's epoch ms globally so the header "live" dot can read it
  // without re-fetching. ts is colon-free (e.g. 2026-06-15T08-31-19Z).
  const newest = runs[runs.length - 1]?.ts;
  if (newest) {
    const iso = newest.replace(/T(\d\d)-(\d\d)-(\d\d)Z$/, "T$1:$2:$3Z");
    const ms = Date.parse(iso);
    if (!Number.isNaN(ms)) (globalThis as Record<string, unknown>).__lemonLastRunMs = ms;
  }
  return runs;
}

export async function loadInflight(rel = "./inflight.json"): Promise<Inflight | null> {
  try {
    const r = await fetch(`${rel}?t=${Date.now()}`, { cache: "no-store" });
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

// MEAN score per cell, not best-of. Averaging the *maximum* of several noisy
// trials is a winner's-curse: it systematically overstates every cell and lets a
// single lucky run define the score. meanPer averages all scored trials instead,
// and returns a representative Run (the latest in the cell) with score_pct set to
// that mean - so existing consumers that read a Run keep working. n is the trial
// count, attached for callers that want to gate/annotate low-sample cells.
export function meanPer<K>(runs: Run[], keyFn: (r: Run) => K): Map<K, Run & { n: number }> {
  const groups = new Map<K, Run[]>();
  for (const r of runs) {
    const k = keyFn(r);
    (groups.get(k) ?? groups.set(k, []).get(k)!).push(r);
  }
  const out = new Map<K, Run & { n: number }>();
  for (const [k, rs] of groups) {
    const scored = rs.filter((r) => Number.isFinite(r.score_pct));
    if (!scored.length) continue;
    const mean = scored.reduce((s, r) => s + r.score_pct, 0) / scored.length;
    const rep = rs[rs.length - 1];
    out.set(k, { ...rep, score_pct: Math.round(mean * 10) / 10, n: scored.length });
  }
  return out;
}

// Bayesian-shrunk score: pulls low-coverage rows toward the global mean.
//   shrunk = (n*avg + C*mu) / (n + C),  C=3 pseudo-evals
export function bayesianRank(rows: Array<{ avg: number; count: number }>, allMean: number, C = 3) {
  return rows.map((r) => ({
    ...r,
    shrunk: (r.count * r.avg + C * allMean) / (r.count + C),
  }));
}

// --- One-board suite policy (shared by the homepage Leaderboard and /cloud) ----
// Evals that measure the scoring ENVIRONMENT rather than the model give every arm
// the same uninformative score, so they're excluded from rankings. port-scanner
// needs live sockets / a firewall timeout that don't behave on the Windows scoring
// box (~every arm lands at 20%).
export const EXCLUDED_EVALS = new Set(["port-scanner"]);
// Separate suites that must NOT blend into the main ranking: the deliberately-harder
// `hard-tier` set (a different, smaller eval list) and one-off `showcase` runs.
export const SEPARATE_TAGS = new Set(["hard-tier", "showcase"]);
// A run belongs on the unified leaderboard iff it's in the main suite.
export const isMainSuite = (r: Run) => !SEPARATE_TAGS.has(r.tag) && !EXCLUDED_EVALS.has(r.eval);

// Format a per-task USD cost compactly (more precision for sub-cent values).
export function fmtCost(c: number | null | undefined): string {
  if (c === null || c === undefined || !Number.isFinite(c)) return "-";
  return c >= 0.01 ? `$${c.toFixed(3)}` : `$${c.toFixed(5)}`;
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
  if (s === null || s === undefined || !Number.isFinite(s)) return "-";
  if (s < 60) return `${Math.round(s)}s`;
  const m = Math.floor(s / 60);
  const r = Math.round(s % 60);
  return `${m}m ${r}s`;
}
