// Build-time data layer. Every number on the site is computed here from the repo's data files
// (runs.jsonl, studio/summary.json) when `next build` runs. Nothing is typed in by hand.
// Server-only: it reads the filesystem, so only server components import it.
import fs from "node:fs";
import path from "node:path";
import { bootMeanCI, mean, median, round } from "./stats";

// ---------------------------------------------------------------- loading

function findRoot(): string {
  for (const c of [path.resolve(process.cwd(), ".."), process.cwd()]) {
    if (fs.existsSync(path.join(c, "runs.jsonl"))) return c;
  }
  throw new Error("runs.jsonl not found next to dashboard-next/");
}
const ROOT = findRoot();

export type Run = {
  run_id: string;
  ts: string;
  eval: string;
  harness: string;
  model: string;
  tag: string;
  host: string;
  wall_seconds: number;
  score_pct: number | string;
  cost_usd?: number;
  tokens_in?: number;
  tokens_out?: number;
  mix?: { pipeline: string; primary: string; architect?: string | null; critic?: string | null; judge?: string | null };
  telemetry?: { gpu_power_avg_w?: number; gpu_mem_peak_mb?: number };
};

let _runs: Run[] | null = null;
export function runs(): Run[] {
  if (_runs) return _runs;
  const out: Run[] = [];
  for (const line of fs.readFileSync(path.join(ROOT, "runs.jsonl"), "utf8").split("\n")) {
    const t = line.trim();
    if (!t) continue;
    try {
      const r = JSON.parse(t) as Run;
      r.harness ||= "pi";
      r.host ||= "4070"; // legacy rows were all the 4070
      out.push(r);
    } catch {
      /* malformed line */
    }
  }
  _runs = out;
  return out;
}

const score = (r: Run) => (typeof r.score_pct === "number" && Number.isFinite(r.score_pct) ? r.score_pct : 0);
const scored = (r: Run) => typeof r.score_pct === "number" && Number.isFinite(r.score_pct);

const tsToDate = (ts: string) => ts.slice(0, 10);
function dateRange(rs: Run[]): [string, string] {
  const t = rs.map((r) => r.ts).sort();
  return [tsToDate(t[0] ?? ""), tsToDate(t[t.length - 1] ?? "")];
}

// Evals that measure the scoring environment, not the model (see FINDINGS-CLOUD.md).
export const EXCLUDED_EVALS = new Set(["port-scanner"]);
export const MIN_EVALS = 8;

// ---------------------------------------------------------------- arms

export type Arm = {
  key: string;
  model: string;
  harness: string;
  kind: "single" | "mix";
  pipeline?: string;
  evals: number;
  n: number;
  failed: number;
  mean: number;
  lo: number | null;
  hi: number | null;
  costPerTask: number | null; // null when the rows carry no cost
  wallMean: number;
  scorePerDollar: number | null;
};

function evalMeans(rs: Run[]): Map<string, number> {
  const by = new Map<string, number[]>();
  for (const r of rs) (by.get(r.eval) ?? by.set(r.eval, []).get(r.eval)!).push(score(r));
  return new Map([...by].map(([k, v]) => [k, mean(v)]));
}

function armOf(rs: Run[], key: string): Arm {
  const em = [...evalMeans(rs).values()];
  const m = mean(em);
  const ci = em.length >= MIN_EVALS ? bootMeanCI(em) : null;
  const cost = rs.reduce((s, r) => s + (r.cost_usd ?? 0), 0);
  const costPerTask = cost > 0 ? cost / rs.length : null;
  const h = rs[0].harness;
  const isMix = !!rs[0].mix || (h.startsWith("cloud-") && h !== "squeezer-cloud");
  return {
    key,
    model: rs[0].model,
    harness: h,
    kind: isMix ? "mix" : "single",
    pipeline: rs[0].mix?.pipeline,
    evals: em.length,
    n: rs.length,
    failed: rs.filter((r) => !scored(r)).length,
    mean: round(m),
    lo: ci ? round(ci[0]) : null,
    hi: ci ? round(ci[1]) : null,
    costPerTask,
    wallMean: round(mean(rs.map((r) => r.wall_seconds ?? 0)), 0),
    scorePerDollar: costPerTask ? round(m / (100 * costPerTask), 0) : null,
  };
}

function armsBy(rs: Run[], keyFn: (r: Run) => string): Arm[] {
  const g = new Map<string, Run[]>();
  for (const r of rs) {
    const k = keyFn(r);
    (g.get(k) ?? g.set(k, []).get(k)!).push(r);
  }
  const arms = [...g].map(([k, v]) => armOf(v, k));
  // same order as bin/cloud-report: arms with an interval first, by lower bound
  arms.sort(
    (a, b) =>
      Number(a.lo === null) - Number(b.lo === null) ||
      (b.lo ?? b.mean) - (a.lo ?? a.mean) ||
      (a.costPerTask ?? 0) - (b.costPerTask ?? 0),
  );
  return arms;
}

// ---------------------------------------------------------------- cloud model comparison

export type Cloud = ReturnType<typeof computeCloud>;
function computeCloud() {
  const all = runs().filter((r) => r.host === "openrouter" && r.tag === "fable-hunt");
  const rs = all.filter((r) => !EXCLUDED_EVALS.has(r.eval));
  const arms = armsBy(rs, (r) => `${r.model}|${r.harness}`);
  const top = arms[0];
  // "tied with the top": the arm's interval reaches the top arm's lower bound
  const tied = arms.filter((a) => a.hi !== null && top.lo !== null && a.hi >= top.lo);
  const singles = arms.filter((a) => a.kind === "single");
  const mixes = arms.filter((a) => a.kind === "mix");
  const bestSingle = [...singles].sort((a, b) => b.mean - a.mean)[0];
  const bestMix = [...mixes].sort((a, b) => b.mean - a.mean)[0];
  const value = [...singles].filter((a) => a.mean >= 85 && a.costPerTask).sort((a, b) => a.costPerTask! - b.costPerTask!)[0];

  const hardRows = runs().filter((r) => r.host === "openrouter" && r.tag === "hard-tier");
  const hard = armsBy(hardRows, (r) => `${r.model}|${r.harness}`);

  return {
    tag: "fable-hunt",
    nRuns: rs.length,
    nExcluded: all.length - rs.length,
    nEvals: new Set(rs.map((r) => r.eval)).size,
    totalCost: rs.reduce((s, r) => s + (r.cost_usd ?? 0), 0),
    dates: dateRange(rs),
    arms,
    tied,
    nSingles: singles.length,
    nMixes: mixes.length,
    bestSingle,
    bestMix,
    value,
    hard: {
      nRuns: hardRows.length,
      nEvals: new Set(hardRows.map((r) => r.eval)).size,
      evals: [...new Set(hardRows.map((r) => r.eval))].sort(),
      dates: dateRange(hardRows),
      arms: hard,
    },
  };
}

// ---------------------------------------------------------------- harness bake-off

function cellMeans(rs: Run[], keyFn: (r: Run) => string) {
  const by = new Map<string, number[]>();
  for (const r of rs) {
    const k = keyFn(r);
    (by.get(k) ?? by.set(k, []).get(k)!).push(score(r));
  }
  return new Map([...by].map(([k, v]) => [k, mean(v)]));
}

export type Paired = {
  label: string;
  a: string;
  b: string;
  cells: number;
  aMean: number;
  bMean: number;
  diff: number;
  lo: number | null;
  hi: number | null;
  aWins: number;
  bWins: number;
  ties: number;
  verdict: "A ahead" | "B ahead" | "too wide to call";
};

function paired(label: string, a: string, b: string, A: Map<string, number>, B: Map<string, number>, keep?: (k: string) => boolean): Paired | null {
  const shared = [...A.keys()].filter((k) => B.has(k) && (!keep || keep(k))).sort();
  if (!shared.length) return null;
  const d = shared.map((k) => A.get(k)! - B.get(k)!);
  const ci = bootMeanCI(d);
  return {
    label,
    a,
    b,
    cells: shared.length,
    aMean: round(mean(shared.map((k) => A.get(k)!))),
    bMean: round(mean(shared.map((k) => B.get(k)!))),
    diff: round(mean(d)),
    lo: ci ? round(ci[0]) : null,
    hi: ci ? round(ci[1]) : null,
    aWins: d.filter((x) => x > 0.5).length,
    bWins: d.filter((x) => x < -0.5).length,
    ties: d.filter((x) => Math.abs(x) <= 0.5).length,
    verdict: !ci ? "too wide to call" : ci[0] > 0 ? "A ahead" : ci[1] < 0 ? "B ahead" : "too wide to call",
  };
}

export type Bakeoff = ReturnType<typeof computeBakeoff>;
function computeBakeoff() {
  // 1. aider vs squeezer, paired on (eval, model) cells where both ran (bin/bakeoff-report)
  const rs = runs().filter((r) => r.host === "openrouter" && r.tag === "bakeoff");
  const key = (r: Run) => `${r.eval}|${r.model}`;
  const A = cellMeans(rs.filter((r) => r.harness === "aider-cloud"), key);
  const B = cellMeans(rs.filter((r) => r.harness === "squeezer-cloud"), key);
  const overall = paired("all models", "aider", "squeezer", A, B)!;
  const models = [...new Set([...A.keys()].map((k) => k.split("|")[1]))].sort();
  const perModel = models
    .map((m) => paired(m, "aider", "squeezer", A, B, (k) => k.endsWith(`|${m}`)))
    .filter((x): x is Paired => !!x)
    .sort((x, y) => y.diff - x.diff);

  // 2. eight agent harnesses on one model (deepseek-v4-pro), plus two vendor CLIs on their own models
  const hb = runs().filter((r) => r.tag === "harness-bakeoff" && !EXCLUDED_EVALS.has(r.eval));
  const harnesses = armsBy(hb, (r) => r.harness);
  // reference: the squeezer loop on the same model, from the main cloud sweep
  const sq = runs().filter(
    (r) => r.tag === "fable-hunt" && r.model === "deepseek-v4-pro" && r.harness === "squeezer-cloud" && !EXCLUDED_EVALS.has(r.eval),
  );
  const squeezerRef = sq.length ? armOf(sq, "squeezer-cloud") : null;

  return {
    paired: overall,
    perModel,
    pairedDates: dateRange(rs),
    pairedRuns: rs.length,
    harnesses,
    harnessRuns: hb.length,
    harnessEvals: new Set(hb.map((r) => r.eval)).size,
    harnessDates: dateRange(hb),
    squeezerRef,
  };
}

// ---------------------------------------------------------------- local 4070

export type LocalModel = {
  model: string;
  evals: number;
  n: number;
  mean: number;
  lo: number | null;
  hi: number | null;
  telemetryN: number;
  powerW: number | null;
  vramPeakGB: number | null;
  wallMedian: number;
  whPerTask: number | null;
};

export type Local = ReturnType<typeof computeLocal>;
function computeLocal() {
  const loc = runs().filter((r) => r.host === "4070");
  const aider = loc.filter((r) => r.harness === "aider");
  const g = new Map<string, Run[]>();
  for (const r of aider) (g.get(r.model) ?? g.set(r.model, []).get(r.model)!).push(r);
  const models: LocalModel[] = [...g].map(([model, rs]) => {
    const em = [...evalMeans(rs).values()];
    const ci = em.length >= MIN_EVALS ? bootMeanCI(em) : null;
    const tel = rs.filter((r) => r.telemetry?.gpu_power_avg_w);
    const powerW = tel.length ? mean(tel.map((r) => r.telemetry!.gpu_power_avg_w!)) : null;
    const vram = tel.length ? Math.max(...tel.map((r) => r.telemetry!.gpu_mem_peak_mb ?? 0)) / 1024 : null;
    const wh = tel.length ? mean(tel.map((r) => (r.telemetry!.gpu_power_avg_w! * r.wall_seconds) / 3600)) : null;
    return {
      model,
      evals: em.length,
      n: rs.length,
      mean: round(mean(em)),
      lo: ci ? round(ci[0]) : null,
      hi: ci ? round(ci[1]) : null,
      telemetryN: tel.length,
      powerW: powerW === null ? null : round(powerW, 0),
      vramPeakGB: vram === null ? null : round(vram, 1),
      wallMedian: round(median(rs.map((r) => r.wall_seconds)), 0),
      whPerTask: wh === null ? null : round(wh, 2),
    };
  });
  models.sort((a, b) => Number(a.lo === null) - Number(b.lo === null) || b.mean - a.mean);

  // harness pairs on the same local model: aider vs pi, paired on evals both ran
  const byHM = (h: string, m: string) => cellMeans(loc.filter((r) => r.harness === h && r.model === m), (r) => r.eval);
  const harnessPairs = [...new Set(loc.filter((r) => r.harness === "pi").map((r) => r.model))]
    .map((m) => paired(m, "aider", "pi", byHM("aider", m), byHM("pi", m)))
    .filter((x): x is Paired => !!x && x.cells >= 3)
    .sort((a, b) => b.cells - a.cells);

  // venue: the squeezer loop on the 4070 (Ollama q4) vs the same model on OpenRouter, same evals
  const VENUE: [string, string][] = [
    ["gpt-oss:20b", "gpt-oss-20b"],
    ["qwen3-coder:30b", "qwen3-coder-30b"],
  ];
  const cloudSq = runs().filter((r) => r.host === "openrouter" && r.harness === "squeezer-cloud" && r.tag === "fable-hunt");
  const venue = VENUE.map(([lm, cm]) =>
    paired(
      lm,
      "4070 (q4)",
      "cloud",
      cellMeans(loc.filter((r) => r.harness === "squeezer-local" && r.model === lm), (r) => r.eval),
      cellMeans(cloudSq.filter((r) => r.model === cm), (r) => r.eval),
    ),
  ).filter((x): x is Paired => !!x);
  const venueLocalRuns = loc.filter((r) => r.harness === "squeezer-local").length;

  return {
    nRuns: loc.length,
    nModels: new Set(loc.map((r) => r.model)).size,
    nEvals: new Set(loc.map((r) => r.eval)).size,
    nHarnesses: new Set(loc.map((r) => r.harness)).size,
    dates: dateRange(loc),
    aiderRuns: aider.length,
    models,
    harnessPairs,
    venue,
    venueLocalRuns,
  };
}

// ---------------------------------------------------------------- Mac Studio tool calling

export type StudioRow = {
  tag: string;
  key: string;
  model: string;
  quant: string;
  gb: string;
  engine: string;
  tools: string;
  suite: string;
  status: string;
  tasks: number;
  expected_tasks: number;
  solved: number;
  wilson95: [number, number];
  checks_passed: number;
  checks_total: number;
  wall_min: number;
  tok_s_over_wall: number | null;
  decode_tok_s: number | null;
  fail_stops: Record<string, number>;
  failed_tasks: string[];
};
export type StudioComparison = {
  name: string;
  a: number;
  b: number;
  note: string;
  n: number;
  diff: number;
  ci: [number, number];
  verdict: string;
};
export type Studio = {
  status: string;
  note: string;
  venue: { name: string; hardware: string; engine: string };
  exploration: Record<string, StudioRow[]>;
  comparisons: StudioComparison[];
  final: { state: string; seed_offset: number; tasks: number; models: StudioRow[]; comparisons: StudioComparison[] };
};

let _studio: Studio | null = null;
export function studio(): Studio {
  if (!_studio) _studio = JSON.parse(fs.readFileSync(path.join(ROOT, "studio", "summary.json"), "utf8")) as Studio;
  return _studio;
}
export const findComparison = (name: string) => studio().comparisons.find((c) => c.name.startsWith(name));

// ---------------------------------------------------------------- memoized entry points

let _cloud: Cloud | null = null;
let _bake: Bakeoff | null = null;
let _local: Local | null = null;
export const cloud = () => (_cloud ??= computeCloud());
export const bakeoff = () => (_bake ??= computeBakeoff());
export const local = () => (_local ??= computeLocal());

export function totals() {
  const rs = runs();
  return {
    runs: rs.length,
    newest: tsToDate([...rs.map((r) => r.ts)].sort().pop() ?? ""),
    studioRows: Object.values(studio().exploration).reduce((s, v) => s + v.reduce((t, r) => t + r.tasks, 0), 0),
  };
}

export const pct = (x: number, d = 0) => `${x.toFixed(d)}%`;
export function fmtCost(c: number | null | undefined) {
  if (c === null || c === undefined) return "n/r";
  return c >= 0.01 ? `$${c.toFixed(3)}` : `$${c.toFixed(4)}`;
}
export const fmtCI = (lo: number | null, hi: number | null, d = 0) =>
  lo === null || hi === null ? "too few evals" : `${lo.toFixed(d)}–${hi.toFixed(d)}`;
export const signed = (x: number, d = 1) => `${x > 0 ? "+" : x < 0 ? "−" : "±"}${Math.abs(x).toFixed(d)}`;
