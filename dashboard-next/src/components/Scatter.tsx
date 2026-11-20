// Score vs cost per task, log-x. Server-rendered SVG; drawn twice (desktop and phone
// geometry) so labels stay legible at both widths.

export type Pt = { x: number; y: number; label: string; mix?: boolean; hi?: boolean; showLabel?: boolean; title: string };

function Plot({ pts, W, H, xTicks, yDomain, labels, fs }: { pts: Pt[]; W: number; H: number; xTicks: number[]; yDomain: [number, number]; labels: boolean; fs: number }) {
  const m = { l: 40, r: 14, t: 26, b: 38 };
  const lx0 = Math.log10(xTicks[0]);
  const lx1 = Math.log10(xTicks[xTicks.length - 1]);
  const X = (v: number) => m.l + ((Math.log10(v) - lx0) / (lx1 - lx0)) * (W - m.l - m.r);
  const Y = (v: number) => m.t + (1 - (v - yDomain[0]) / (yDomain[1] - yDomain[0])) * (H - m.t - m.b);
  const yTicks: number[] = [];
  for (let v = yDomain[0]; v <= yDomain[1]; v += 10) yTicks.push(v);
  // Pareto frontier: best score at or below each cost
  const sorted = [...pts].sort((a, b) => a.x - b.x);
  const front: Pt[] = [];
  for (const p of sorted) if (!front.length || p.y > front[front.length - 1].y) front.push(p);
  const fmt = (v: number) => (v >= 0.01 ? `$${v}` : `$${v}`);
  return (
    <svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label="Mean score against cost per task">
      {yTicks.map((t) => (
        <g key={t}>
          <line className="gridline" x1={m.l} x2={W - m.r} y1={Y(t)} y2={Y(t)} />
          <text className="tick" x={m.l - 6} y={Y(t) + 3.5} textAnchor="end" style={{ fontSize: fs }}>
            {t}
          </text>
        </g>
      ))}
      {xTicks.map((t) => (
        <g key={t}>
          <line className="gridline" x1={X(t)} x2={X(t)} y1={m.t} y2={H - m.b} />
          <text className="tick" x={X(t)} y={H - m.b + 14} textAnchor="middle" style={{ fontSize: fs }}>
            {fmt(t)}
          </text>
        </g>
      ))}
      <line className="axis" x1={m.l} x2={W - m.r} y1={H - m.b} y2={H - m.b} />
      <text className="axlab" x={(W + m.l) / 2} y={H - 6} textAnchor="middle" style={{ fontSize: fs }}>
        mean cost per task (USD, log scale)
      </text>
      <text className="axlab" x={m.l - 30} y={12} textAnchor="start" style={{ fontSize: fs }}>
        mean score %
      </text>
      <polyline className="front" points={front.map((p) => `${X(p.x)},${Y(p.y)}`).join(" ")} />
      {pts.map((p) => (
        <g key={p.label}>
          <circle className={`pt ${p.mix ? "mix" : ""} ${p.hi ? "hi" : ""}`} cx={X(p.x)} cy={Y(p.y)} r={fs * 0.42}>
            <title>{p.title}</title>
          </circle>
        </g>
      ))}
      {labels &&
        pts
          .filter((p) => p.showLabel)
          .map((p) => {
            const right = X(p.x) < W * 0.72;
            const below = p.y > yDomain[1] - 4; // top row is crowded: label under the point
            return (
              <text key={p.label} className="lbl" x={X(p.x) + (below ? 0 : right ? 8 : -8)} y={Y(p.y) + (below ? fs * 1.6 : 3.5)} textAnchor={below ? "middle" : right ? "start" : "end"} style={{ fontSize: fs }}>
                {p.label}
              </text>
            );
          })}
    </svg>
  );
}

export default function Scatter({ pts, xTicks, yDomain }: { pts: Pt[]; xTicks: number[]; yDomain: [number, number] }) {
  return (
    <div className="scatter">
      <div className="hidden sm:block">
        <Plot pts={pts} W={720} H={420} xTicks={xTicks} yDomain={yDomain} labels fs={11} />
      </div>
      <div className="sm:hidden">
        <Plot pts={pts.map((p) => ({ ...p, showLabel: p.showLabel && p.hi }))} W={360} H={300} xTicks={xTicks} yDomain={yDomain} labels fs={10} />
      </div>
    </div>
  );
}
