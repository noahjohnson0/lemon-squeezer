"use client";
import { unique } from "@/lib/data";
import type { Run } from "@/lib/data";

export type FilterState = {
  eval: string;
  harness: string;
  model: string;
  host: string;
};

export default function Filters({
  runs,
  state,
  onChange,
}: {
  runs: Run[];
  state: FilterState;
  onChange: (s: FilterState) => void;
}) {
  const evals = unique(runs.map((r) => r.eval));
  const harnesses = unique(runs.map((r) => r.harness));
  const models = unique(runs.map((r) => r.model));
  const hosts = unique(runs.map((r) => r.host ?? "4070"));
  const sel = (val: string, opts: string[], onPick: (v: string) => void, label: string) => (
    <label className="flex items-center gap-1.5 text-xs">
      <span className="text-[var(--muted)] uppercase tracking-wider text-[10px]">
        {label}
      </span>
      <select
        value={val}
        onChange={(e) => onPick(e.target.value)}
        className="bg-[var(--panel)] border border-[var(--border)] rounded px-2 py-1 text-xs font-mono"
      >
        <option value="">all</option>
        {opts.map((o) => (
          <option key={o} value={o}>
            {o}
          </option>
        ))}
      </select>
    </label>
  );
  const active = state.eval || state.harness || state.model || state.host;
  return (
    <div className="max-w-7xl mx-auto px-6 mt-6">
      <div className="bg-[var(--panel)] border border-[var(--border)] rounded-xl px-4 py-3 flex flex-wrap items-center gap-4">
        <span className="text-[10px] uppercase tracking-wider text-[var(--muted)]">
          Filters
        </span>
        {sel(state.host, hosts, (v) => onChange({ ...state, host: v }), "host")}
        {sel(state.eval, evals, (v) => onChange({ ...state, eval: v }), "eval")}
        {sel(state.harness, harnesses, (v) => onChange({ ...state, harness: v }), "harness")}
        {sel(state.model, models, (v) => onChange({ ...state, model: v }), "model")}
        {active && (
          <button
            onClick={() => onChange({ eval: "", harness: "", model: "", host: "" })}
            className="text-xs text-[var(--accent)] hover:underline ml-auto"
          >
            clear
          </button>
        )}
      </div>
    </div>
  );
}
