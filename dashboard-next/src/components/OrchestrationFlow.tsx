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
type FlowLayout = { height: number; nodes: PositionedNode[] };

const WIDTH = 640;
const NODE_W = 150;
const NODE_H = 58;
const NODE_GAP_Y = 12;
const WORKSPACE_X = 26;
const WORKSPACE_Y = 24;
const WORKSPACE_W = 588;
const WORKSPACE_MARGIN = 18;
const MIN_HEIGHT = 196;

const ROLE_ORDER: Role[] = ["planner", "implementer", "critic", "judge", "tester"];
const ROLE_META: Record<Role, { label: string; color: string }> = {
  planner: { label: "Planner", color: "var(--accent-3, #79c0ff)" }, implementer: { label: "Implementer", color: "var(--accent, #d8e84a)" },
  critic: { label: "Critic", color: "var(--warn, #d2a8ff)" }, judge: { label: "Judge", color: "var(--accent-2, #7ee0b8)" },
  tester: { label: "Tester", color: "var(--good, #56d364)" },
};

function safeId(value: string): string {
  return value.replace(/[^a-zA-Z0-9_-]/g, "-");
}

function edgeKey(from: string, to: string): string {
  return `${from}\u0000${to}`;
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function isLevelingBackEdge(edge: FlowEdge, levels: Map<string, number>, originalOrder: Map<string, number>, reciprocalEdges: Set<string>): boolean {
  const fromOrder = originalOrder.get(edge.from) ?? 0;
  const toOrder = originalOrder.get(edge.to) ?? 0;
  const hasReciprocal = reciprocalEdges.has(edgeKey(edge.to, edge.from));

  if (hasReciprocal) return toOrder < fromOrder;

  return toOrder <= fromOrder && (levels.get(edge.to) ?? 0) <= (levels.get(edge.from) ?? 0);
}

function layoutNodes(pattern: Pattern): FlowLayout {
  const originalOrder = new Map(pattern.nodes.map((node, index) => [node.id, index]));
  const levels = new Map(pattern.nodes.map((node) => [node.id, 0]));
  const edgeKeys = new Set(pattern.edges.map((edge) => edgeKey(edge.from, edge.to)));

  // Repeatedly relax only forward edges so reciprocal return edges cannot collapse cycles into one level.
  for (let pass = 0; pass < pattern.nodes.length + pattern.edges.length; pass += 1) {
    let changed = false;
    for (const edge of pattern.edges) {
      if (!levels.has(edge.from) || !levels.has(edge.to)) continue;
      if (isLevelingBackEdge(edge, levels, originalOrder, edgeKeys)) continue;

      const next = Math.min((levels.get(edge.from) ?? 0) + 1, pattern.nodes.length - 1);
      if (next > (levels.get(edge.to) ?? 0)) {
        levels.set(edge.to, next);
        changed = true;
      }
    }
    if (!changed) break;
  }

  const maxLevel = Math.max(1, ...Array.from(levels.values()));
  const minNodeX = WORKSPACE_X + WORKSPACE_MARGIN + NODE_W / 2;
  const maxNodeX = WORKSPACE_X + WORKSPACE_W - WORKSPACE_MARGIN - NODE_W / 2;
  const groups = new Map<number, FlowNode[]>();
  for (const node of pattern.nodes) {
    const level = levels.get(node.id) ?? 0;
    groups.set(level, [...(groups.get(level) ?? []), node]);
  }

  const rowCount = Math.max(1, ...Array.from(groups.values()).map((nodes) => nodes.length));
  const rowStackHeight = rowCount * NODE_H + Math.max(0, rowCount - 1) * NODE_GAP_Y;
  const height = Math.max(MIN_HEIGHT, rowStackHeight + 62);
  const nodes = Array.from(groups.entries()).flatMap(([level, nodes]) => {
    const sorted = [...nodes].sort((a, b) => (originalOrder.get(a.id) ?? 0) - (originalOrder.get(b.id) ?? 0));
    const stackHeight = sorted.length * NODE_H + Math.max(0, sorted.length - 1) * NODE_GAP_Y;
    const firstY = (height - stackHeight) / 2 + NODE_H / 2;

    return sorted.map((node, index) => {
      return {
        ...node,
        level,
        x: clamp(minNodeX + (level / maxLevel) * (maxNodeX - minNodeX), minNodeX, maxNodeX),
        y: firstY + index * (NODE_H + NODE_GAP_Y),
      };
    });
  });

  return { height, nodes };
}

function forwardEdgePath(from: PositionedNode, to: PositionedNode): string {
  const direction = to.x >= from.x ? 1 : -1;
  const x1 = from.x + (direction * NODE_W) / 2;
  const y1 = from.y;
  const x2 = to.x - (direction * NODE_W) / 2;
  const y2 = to.y;
  const bend = Math.max(52, Math.abs(x2 - x1) * 0.45);
  return `M ${x1} ${y1} C ${x1 + direction * bend} ${y1}, ${x2 - direction * bend} ${y2}, ${x2} ${y2}`;
}

function returnEdgePath(from: PositionedNode, to: PositionedNode, height: number): string {
  const direction = to.x >= from.x ? 1 : -1;
  const x1 = from.x + (direction * NODE_W) / 2;
  const y1 = from.y + 8;
  const x2 = to.x - (direction * NODE_W) / 2;
  const y2 = to.y + 8;
  const bowY = clamp(Math.max(from.y, to.y) + 58, WORKSPACE_Y + NODE_H, height - 28);
  return `M ${x1} ${y1} C ${x1 + direction * 38} ${bowY}, ${x2 - direction * 38} ${bowY}, ${x2} ${y2}`;
}

function isRenderedBackEdge(from: PositionedNode, to: PositionedNode): boolean {
  return to.level <= from.level;
}

function PatternCard({ pattern, index }: { pattern: Pattern; index: number }): JSX.Element {
  const shouldReduceMotion = useReducedMotion();
  const layout = useMemo(() => layoutNodes(pattern), [pattern]);
  const { height, nodes } = layout;
  const nodeById = useMemo(() => new Map(nodes.map((node) => [node.id, node])), [nodes]);
  const markerId = `orchestration-arrow-${safeId(pattern.key)}`;
  const flowClass = shouldReduceMotion ? "" : "orchestration-flow-line";
  const workspaceHeight = height - WORKSPACE_Y * 2;
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
        <svg viewBox={`0 0 ${WIDTH} ${height}`} role="img" aria-labelledby={`${markerId}-title ${markerId}-desc`} className="h-auto w-full">
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

          <rect x={WORKSPACE_X} y={WORKSPACE_Y} width={WORKSPACE_W} height={workspaceHeight} rx="22" fill="rgba(255,255,255,0.025)" stroke="var(--border)" strokeDasharray="7 9" opacity="0.9" />
          <path d={`M 56 ${height / 2} H 584`} stroke="var(--border)" strokeDasharray="4 10" opacity="0.7" />
          <text x="42" y={WORKSPACE_Y + 20} fill="var(--muted)" fontSize="11" fontFamily="monospace">
            workspace
          </text>

          {pattern.edges.map((edge, edgeIndex) => {
            const from = nodeById.get(edge.from);
            const to = nodeById.get(edge.to);
            if (!from || !to) return null;
            const isBackEdge = isRenderedBackEdge(from, to);
            const path = isBackEdge ? returnEdgePath(from, to, height) : forwardEdgePath(from, to);
            const midX = (from.x + to.x) / 2;
            const midY = isBackEdge
              ? clamp(Math.max(from.y, to.y) + 50, WORKSPACE_Y + 34, height - 18)
              : (from.y + to.y) / 2 - 12 - (edgeIndex % 2) * 8;
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
                {!shouldReduceMotion ? (
                  <circle r="4" fill="var(--accent,#d8e84a)" opacity="0.78" filter={`url(#${markerId}-glow)`}>
                    <animateMotion dur={`${1.9 + edgeIndex * 0.18}s`} path={path} repeatCount="indefinite" />
                  </circle>
                ) : null}
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
