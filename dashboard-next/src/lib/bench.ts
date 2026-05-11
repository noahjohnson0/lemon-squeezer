// Bench data layer: types + loader for the rag-bench sweeps view.
// Reads ./bench-data.json (relative), produced at build-time by
// dashboard-next/scripts/build-bench-data.js.

export type PerQuestion = {
  i: number;
  id: string;
  question: string;
  answer_value: string;
  model_answer: string;
  hit: boolean;
  matched_alias: string | null;
  wall_seconds: number;
  tokens_in: number;
  tokens_out: number;
  tool_calls: number;
  exit_code: number;
};

export type Sweep = {
  sweep_id: string;
  ts: string;
  qset: string;
  model: string;
  harness: string;
  tag: string | null;
  corpora: string[];
  n: number;
  hits: number;
  accuracy: number;
  score_pct: number;
  wall_seconds_total: number;
  wall_seconds_mean: number;
  tokens_in_total: number;
  tokens_out_total: number;
  tool_calls_total: number;
  host?: string;
  base_url?: string;
  per_q: PerQuestion[];
};

export type Question = {
  id: string;
  question: string;
  answer_value: string;
  domain: string | null;
  normalized_aliases: string[] | null;
  aliases: string[] | null;
  expected_corpora: string[] | null;
};

export type BenchData = {
  generated_at: string;
  sweeps: Sweep[];
  qsets: Record<string, { questions: Question[] }>;
};

export async function loadBenchData(): Promise<BenchData> {
  // The page is served at /bench/ (with trailingSlash). A bare "./bench-data.json" would
  // resolve to /bench/bench-data.json — but the file lives at the site root (next to
  // runs.jsonl). Use "../bench-data.json" so it works under both dev and the
  // /lemon-squeezer basePath on Pages.
  const r = await fetch(`../bench-data.json?t=${Date.now()}`, { cache: "no-store" });
  if (!r.ok) throw new Error(`bench-data.json ${r.status}`);
  return (await r.json()) as BenchData;
}

/** Pretty-print accuracy: "27.5%" given 0.2745. */
export function pctAcc(a: number | undefined | null): string {
  if (a === null || a === undefined || !Number.isFinite(a)) return "–";
  return `${(100 * a).toFixed(1)}%`;
}

/** Short timestamp: "05-11 17:34". Input format: "2026-05-11T17-34-17Z". */
export function shortTs(ts: string): string {
  // Replace the time dashes back to colons so Date can parse it
  const m = ts.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2})-(\d{2})-(\d{2})Z?$/);
  if (!m) return ts;
  return `${m[2]}-${m[3]} ${m[4]}:${m[5]}`;
}

/** Build domain breakdown for a gridown-style sweep: { domain: {hits, n} } */
export function domainBreakdown(
  sweep: Sweep,
  qset: { questions: Question[] }
): Map<string, { hits: number; n: number }> {
  const dom = new Map<string, string>();
  for (const q of qset.questions) {
    if (q.domain) dom.set(q.id, q.domain);
  }
  const out = new Map<string, { hits: number; n: number }>();
  for (const r of sweep.per_q) {
    const d = dom.get(r.id) ?? "unknown";
    const cur = out.get(d) ?? { hits: 0, n: 0 };
    cur.n += 1;
    if (r.hit) cur.hits += 1;
    out.set(d, cur);
  }
  return out;
}

/** Group sweeps that share (qset, model) but differ on tag for comparison. */
export function comparisonGroups(sweeps: Sweep[]): Map<string, Sweep[]> {
  const m = new Map<string, Sweep[]>();
  for (const s of sweeps) {
    const key = `${s.qset}|${s.model}`;
    const arr = m.get(key) ?? [];
    arr.push(s);
    m.set(key, arr);
  }
  // Only keep groups with at least 2 distinct tags
  for (const [k, arr] of m) {
    const tags = new Set(arr.map((s) => s.tag ?? "default"));
    if (tags.size < 2) m.delete(k);
  }
  return m;
}

const SCORE_PALETTE = (s: number): "good" | "mid" | "bad" => {
  if (!Number.isFinite(s)) return "bad";
  if (s >= 70) return "good";
  if (s >= 40) return "mid";
  return "bad";
};
export const scoreClassForAcc = (acc: number): "good" | "mid" | "bad" =>
  SCORE_PALETTE(100 * acc);
