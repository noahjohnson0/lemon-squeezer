"use client";

import type { JSX } from "react";
import { useMemo } from "react";
import { motion, useReducedMotion } from "framer-motion";

export type FlowNode = { id: string; label: string; role: "planner" | "implementer" | "critic" | "judge" | "tester" };
export type FlowEdge = { from: string; to: string; label?: string };
export type Pattern = {
  key: string; title: string; tagline: string; nodes: FlowNode[]; edges: FlowEdge[];
  result?: { arm: string; score: number; cost: number };
};

type Role = FlowNode["role"];
type PositionedNode = FlowNode & { x: number; y: number; level: number };

const WIDTH = 640;
const HEIGHT = 260;
const NODE_W = 132;
const NODE_H = 52;
const PAD_X = 92;

const ROLE_ORDER: Role[] = ["planner", "implementer", "critic", "judge", "tester"];
const ROLE_META: Record<Role, { label: string; color: string }> = {
  planner: { label: "Planner", color: "var(--accent-3, #79c0ff)" }, implementer: { label: "Implementer", color: "var(--accent, #d8e84a)" },
  critic: { label: "Critic", color: "var(--warn, #d2a8ff)" }, judge: { label: "Judge", color: "var(--accent-2, #7ee0b8)" },
  tester: { label: "Tester", color: "var(--good, #56d364)" },
};

function safeId(value: string): string {
  return value.replace(/[^a-zA-Z0-9_-]/g, "-");
}

function layoutNodes(pattern: Pattern): PositionedNode[] {
  const originalOrder = new Map(pattern.nodes.map((node, index) => [node.id, index]));
  const levels = new Map(pattern.nodes.map((node) => [node.id, 0]));

  // Repeatedly relax edge levels so downstream nodes move right, with a cap for cycles.
  for (let pass = 0; pass < pattern.nodes.length + pattern.edges.length; pass += 1) {
    let changed = false;
    for (const edge of pattern.edges) {
      if (!levels.has(edge.from) || !levels.has(edge.to)) continue;
      const next = Math.min((levels.get(edge.from) ?? 0) + 1, pattern.nodes.length - 1);
      if (next > (levels.get(edge.to) ?? 0)) {
        levels.set(edge.to, next);
        changed = true;
      }
    }
    if (!changed) break;
  }

  const maxLevel = Math.max(1, ...Array.from(levels.values()));
  const groups = new Map<number, FlowNode[]>();
  for (const node of pattern.nodes) {
    const level = levels.get(node.id) ?? 0;
    groups.set(level, [...(groups.get(level) ?? []), node]);
  }

  return Array.from(groups.entries()).flatMap(([level, nodes]) => {
    const sorted = [...nodes].sort((a, b) => (originalOrder.get(a.id) ?? 0) - (originalOrder.get(b.id) ?? 0));
    return sorted.map((node, index) => {
      const top = 64;
      const usable = HEIGHT - 112;
      return {
        ...node,
        level,
        x: PAD_X + (level / maxLevel) * (WIDTH - PAD_X * 2),
        y: top + ((index + 1) * usable) / (sorted.length + 1),
      };
    });
  });
}

function edgePath(from: PositionedNode, to: PositionedNode): string {
  const x1 = from.x + NODE_W / 2;
  const y1 = from.y;
  const x2 = to.x - NODE_W / 2;
  const y2 = to.y;
  const bend = Math.max(52, Math.abs(x2 - x1) * 0.45);
  return `M ${x1} ${y1} C ${x1 + bend} ${y1}, ${x2 - bend} ${y2}, ${x2} ${y2}`;
}

function PatternCard({ pattern, index }: { pattern: Pattern; index: number }): JSX.Element {
  const shouldReduceMotion = useReducedMotion();
  const nodes = useMemo(() => layoutNodes(pattern), [pattern]);
  const nodeById = useMemo(() => new Map(nodes.map((node) => [node.id, node])), [nodes]);
  const markerId = `orchestration-arrow-${safeId(pattern.key)}`;
  const flowClass = shouldReduceMotion ? "" : "orchestration-flow-line";
  const scoreTone =
    pattern.result && pattern.result.score >= 95
      ? "bg-[var(--good,#56d364)] text-[#06120a]"
      : "bg-[var(--accent-2,#7ee0b8)] text-[#06120a]";

  return (
    <motion.article initial={shouldReduceMotion ? false : { opacity: 0, y: 14, scale: 0.98 }} animate={{ opacity: 1, y: 0, scale: 1 }} transition={{ duration: 0.45, delay: index * 0.06, ease: "easeOut" }} className="rounded-[0.9rem] border border-[var(--border)] bg-[linear-gradient(145deg,var(--panel),var(--panel-2))] p-4 shadow-[0_18px_50px_rgba(0,0,0,0.18)]">
      <div className="mb-3 flex items-start justify-between gap-3">
        <div>
          <h3 className="text-base font-semibold text-[var(--text)]">{pattern.title}</h3>
          <p className="mt-1 text-sm text-[var(--muted)]">{pattern.tagline}</p>
        </div>
        {pattern.result ? (
          <div className="flex shrink-0 items-center gap-1.5 rounded-full border border-[var(--border)] bg-[var(--panel)] px-2.5 py-1 text-[11px] tabular-nums" title={`${pattern.result.arm}: ${pattern.result.score}% at $${pattern.result.cost}/task`}>
            <span className={`rounded-full px-1.5 py-0.5 font-bold ${scoreTone}`}>
              {pattern.result.score}%
            </span>
            <span className="font-mono text-[var(--muted)]">${pattern.result.cost}/task</span>
          </div>
        ) : null}
      </div>

      <div className="overflow-hidden rounded-xl border border-[var(--border)] bg-[radial-gradient(circle_at_20%_25%,rgba(121,192,255,0.13),transparent_32%),radial-gradient(circle_at_80%_70%,rgba(126,224,184,0.12),transparent_34%),var(--panel-2)]">
        <svg viewBox={`0 0 ${WIDTH} ${HEIGHT}`} role="img" aria-labelledby={`${markerId}-title ${markerId}-desc`} className="h-auto w-full">
          <title id={`${markerId}-title`}>{pattern.title} orchestration flow</title>
          <desc id={`${markerId}-desc`}>{pattern.tagline}</desc>
          <defs>
            <marker id={markerId} markerHeight="8" markerWidth="8" orient="auto" refX="7" refY="4" viewBox="0 0 8 8">
              <path d="M 0 0 L 8 4 L 0 8 z" fill="var(--muted)" />
            </marker>
            <filter id={`${markerId}-glow`} x="-40%" y="-40%" width="180%" height="180%">
              <feGaussianBlur stdDeviation="2.6" result="blur" />
              <feMerge><feMergeNode in="blur" /><feMergeNode in="SourceGraphic" /></feMerge>
            </filter>
          </defs>

          <rect x="26" y="34" width="588" height="188" rx="22" fill="rgba(255,255,255,0.025)" />
          <path d="M 56 130 H 584" stroke="var(--border)" strokeDasharray="4 10" opacity="0.75" />
          <text x="42" y="54" fill="var(--muted)" fontSize="11" fontFamily="monospace">
            workspace
          </text>

          {pattern.edges.map((edge, edgeIndex) => {
            const from = nodeById.get(edge.from);
            const to = nodeById.get(edge.to);
            if (!from || !to) return null;
            const path = edgePath(from, to);
            const midX = (from.x + to.x) / 2;
            const midY = (from.y + to.y) / 2 - 10 - (edgeIndex % 2) * 8;
            return (
              <g key={`${edge.from}-${edge.to}-${edgeIndex}`}>
                <path d={path} fill="none" markerEnd={`url(#${markerId})`} stroke="var(--muted)" strokeLinecap="round" strokeWidth="2.4" opacity="0.55" />
                <path
                  className={flowClass}
                  d={path}
                  fill="none"
                  markerEnd={`url(#${markerId})`}
                  stroke="var(--accent-3,#79c0ff)"
                  strokeLinecap="round"
                  strokeWidth="2.8"
                  strokeDasharray="12 14"
                  filter={`url(#${markerId}-glow)`}
                />
                {edge.label ? (
                  <text x={midX} y={midY} fill="var(--muted)" fontSize="11" textAnchor="middle" paintOrder="stroke" stroke="var(--panel-2)" strokeWidth="5">
                    {edge.label}
                  </text>
                ) : null}
              </g>
            );
          })}

          {nodes.map((node) => {
            const role = ROLE_META[node.role];
            return (
              <g key={node.id} transform={`translate(${node.x - NODE_W / 2} ${node.y - NODE_H / 2})`}>
                <rect width={NODE_W} height={NODE_H} rx="14" fill={role.color} filter={`url(#${markerId}-glow)`} />
                <rect x="3" y="3" width={NODE_W - 6} height={NODE_H - 6} rx="11" fill="none" stroke="rgba(0,0,0,0.28)" />
                <text x="14" y="22" fill="#071016" fontSize="13" fontWeight="700">
                  {node.label}
                </text>
                <text x="14" y="38" fill="rgba(7,16,22,0.72)" fontSize="10" fontFamily="monospace">
                  {role.label}
                </text>
              </g>
            );
          })}
        </svg>
      </div>
    </motion.article>
  );
}

export default function OrchestrationFlow({ patterns }: { patterns: Pattern[] }): JSX.Element {
  return (
    <section className="max-w-7xl mx-auto px-6 mt-12">
      <style>{`
        @keyframes orchestrationDash {
          to { stroke-dashoffset: -52; }
        }
        .orchestration-flow-line {
          animation: orchestrationDash 1.6s linear infinite;
        }
      `}</style>
      <div className="mb-4 flex flex-wrap items-center gap-3 text-xs">
        {ROLE_ORDER.map((role) => (
          <div key={role} className="flex items-center gap-1.5">
            <span
              className="inline-block h-2.5 w-2.5 rounded-full shadow-[0_0_8px_currentColor]"
              style={{ background: ROLE_META[role].color, color: ROLE_META[role].color }}
            />
            <span className="text-[var(--muted)]">{ROLE_META[role].label}</span>
          </div>
        ))}
      </div>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        {patterns.map((pattern, index) => (
          <PatternCard key={pattern.key} pattern={pattern} index={index} />
        ))}
      </div>
    </section>
  );
}
