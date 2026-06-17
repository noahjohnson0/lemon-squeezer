"use client";
import { Sweep, pctAcc, shortTs, scoreClassForAcc } from "@/lib/bench";

type SortKey =
  | "ts"
  | "model"
  | "qset"
  | "tag"
  | "accuracy"
  | "n"
  | "wall"
  | "tokens"
  | "tool_calls";

export type SweepsTableSort = { key: SortKey; dir: "asc" | "desc" };

type Props = {
  sweeps: Sweep[];
  sort: SweepsTableSort;
  onSortChange: (s: SweepsTableSort) => void;
  onSelect: (sweepId: string) => void;
  selectedId?: string | null;
};

const headers: { key: SortKey; label: string; align: "left" | "right" }[] = [
  { key: "ts", label: "when", align: "left" },
  { key: "model", label: "model", align: "left" },
  { key: "qset", label: "qset", align: "left" },
  { key: "tag", label: "tag", align: "left" },
  { key: "accuracy", label: "acc", align: "right" },
  { key: "n", label: "n", align: "right" },
  { key: "wall", label: "wall μ", align: "right" },
  { key: "tokens", label: "tokens in/out", align: "right" },
  { key: "tool_calls", label: "tools", align: "right" },
];

function sortSweeps(sweeps: Sweep[], sort: SweepsTableSort): Sweep[] {
  const out = [...sweeps];
  const mul = sort.dir === "asc" ? 1 : -1;
  out.sort((a, b) => {
    let av: number | string = 0;
    let bv: number | string = 0;
    switch (sort.key) {
      case "ts":
        av = a.ts; bv = b.ts; break;
      case "model":
        av = a.model; bv = b.model; break;
      case "qset":
        av = a.qset; bv = b.qset; break;
      case "tag":
        av = a.tag ?? ""; bv = b.tag ?? ""; break;
      case "accuracy":
        av = a.accuracy_judged ?? a.accuracy ?? 0; bv = b.accuracy_judged ?? b.accuracy ?? 0; break;
      case "n":
        av = a.n; bv = b.n; break;
      case "wall":
        av = a.wall_seconds_mean ?? 0; bv = b.wall_seconds_mean ?? 0; break;
      case "tokens":
        av = (a.tokens_in_total ?? 0) + (a.tokens_out_total ?? 0);
        bv = (b.tokens_in_total ?? 0) + (b.tokens_out_total ?? 0);
        break;
      case "tool_calls":
        av = a.tool_calls_total ?? 0; bv = b.tool_calls_total ?? 0; break;
    }
    if (typeof av === "string" && typeof bv === "string") return mul * av.localeCompare(bv);
    return mul * ((av as number) - (bv as number));
  });
  return out;
}

export default function SweepsTable({ sweeps, sort, onSortChange, onSelect, selectedId }: Props) {
  const sorted = sortSweeps(sweeps, sort);

  function clickHeader(k: SortKey) {
    if (sort.key === k) {
      onSortChange({ key: k, dir: sort.dir === "asc" ? "desc" : "asc" });
    } else {
      // numeric cols default to desc; text cols to asc
      const desc = ["accuracy", "n", "wall", "tokens", "tool_calls", "ts"];
      onSortChange({ key: k, dir: desc.includes(k) ? "desc" : "asc" });
    }
  }

  return (
    <div className="bg-[var(--panel)] border border-[var(--border)] rounded-xl overflow-hidden">
      <div className="overflow-x-auto">
        <table className="w-full text-xs">
          <thead className="text-[10px] uppercase tracking-wider text-[var(--muted)] border-b border-[var(--border)]">
            <tr>
              {headers.map((h) => {
                const active = sort.key === h.key;
                const arrow = active ? (sort.dir === "asc" ? "↑" : "↓") : "";
                return (
                  <th
                    key={h.key}
                    onClick={() => clickHeader(h.key)}
                    className={`px-3 py-3 ${h.align === "right" ? "text-right" : "text-left"} cursor-pointer select-none hover:text-[var(--text)] ${active ? "text-[var(--accent)]" : ""}`}
                  >
                    {h.label} {arrow}
                  </th>
                );
              })}
            </tr>
          </thead>
          <tbody>
            {sorted.length === 0 && (
              <tr>
                <td colSpan={headers.length} className="px-3 py-6 text-center text-[var(--muted)]">
                  no sweeps match the current filter
                </td>
              </tr>
            )}
            {sorted.map((s) => {
              const acc = s.accuracy_judged ?? s.accuracy;  // prefer LLM-judged
              const cls = scoreClassForAcc(acc);
              const selected = s.sweep_id === selectedId;
              return (
                <tr
                  key={s.sweep_id}
                  onClick={() => onSelect(s.sweep_id)}
                  className={`border-b border-[var(--border)] cursor-pointer hover:bg-[var(--panel-2)] ${selected ? "bg-[var(--panel-2)]" : ""}`}
                >
                  <td className="px-3 py-2 font-mono text-[var(--muted)] whitespace-nowrap">
                    {shortTs(s.ts)}
                  </td>
                  <td className="px-3 py-2 font-mono whitespace-nowrap">{s.model}</td>
                  <td className="px-3 py-2">
                    <span className="chip">{s.qset}</span>
                  </td>
                  <td className="px-3 py-2">
                    {s.tag ? <span className="chip">{s.tag}</span> : <span className="text-[var(--muted)]">-</span>}
                  </td>
                  <td className="px-3 py-2 text-right">
                    <span
                      className={`score-${cls} px-2 py-1 rounded text-xs font-bold tabular-nums`}
                      title={s.accuracy_judged !== undefined ? `LLM-judged; substring ${pctAcc(s.accuracy)}` : "substring/alias match"}
                    >
                      {pctAcc(acc)}
                    </span>
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    <span className="text-[var(--text)]">{s.hits}</span>
                    <span className="text-[var(--muted)]">/{s.n}</span>
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums text-[var(--muted)]">
                    {s.wall_seconds_mean?.toFixed(1) ?? "-"}s
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums text-[var(--muted)] whitespace-nowrap">
                    {(s.tokens_in_total ?? 0).toLocaleString()}/{(s.tokens_out_total ?? 0).toLocaleString()}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums text-[var(--muted)]">
                    {s.tool_calls_total ?? "-"}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
