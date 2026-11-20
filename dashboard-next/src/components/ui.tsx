import Link from "next/link";
import type { ReactNode } from "react";

// basePath for plain <a href> to static files (Link adds it on its own)
export const BASE = process.env.NODE_ENV === "production" ? "/lemon-squeezer" : "";
export const fileHref = (p: string) => `${BASE}/${p.replace(/^\//, "")}`;

// ------------------------------------------------------------ status labels

export type Status = "explore" | "pending" | "wide" | "solid" | "hist";
const STATUS_TEXT: Record<Status, string> = {
  explore: "Exploration",
  pending: "Final pass pending",
  wide: "Too wide to call",
  solid: "CI clears zero",
  hist: "Historical snapshot",
};
const STATUS_ICON: Record<Status, ReactNode> = {
  explore: <circle cx="6" cy="6" r="4.5" fill="none" stroke="currentColor" strokeWidth="1.6" strokeDasharray="2 1.6" />,
  pending: (
    <>
      <circle cx="6" cy="6" r="4.6" fill="none" stroke="currentColor" strokeWidth="1.4" />
      <path d="M6 3.4V6l1.8 1.2" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
    </>
  ),
  wide: <path d="M1.5 6h9M1.5 3.5v5M10.5 3.5v5" fill="none" stroke="currentColor" strokeWidth="1.5" />,
  solid: <path d="M2 6.3l2.6 2.5L10 3.2" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />,
  hist: <path d="M2 3h8M2 6h8M2 9h5" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />,
};

export function Chip({ s, children }: { s: Status; children?: ReactNode }) {
  return (
    <span className={`chip chip-${s}`}>
      <svg viewBox="0 0 12 12" aria-hidden="true">{STATUS_ICON[s]}</svg>
      {children ?? STATUS_TEXT[s]}
    </span>
  );
}

// ------------------------------------------------------------ page furniture

export function StudyHead({
  kicker,
  title,
  dek,
  chips,
  meta,
  toc,
}: {
  kicker: string;
  title: string;
  dek: ReactNode;
  chips?: ReactNode;
  meta: [string, ReactNode][];
  toc?: [string, string][];
}) {
  return (
    <header className="study-head col-wide">
      <div className="col" style={{ marginLeft: 0 }}>
        <div className="kicker">{kicker}</div>
        <h1>{title}</h1>
        <p className="dek">{dek}</p>
        {chips && <div className="chips">{chips}</div>}
      </div>
      <dl className="meta-grid">
        {meta.map(([k, v]) => (
          <div key={k}>
            <dt>{k}</dt>
            <dd>{v}</dd>
          </div>
        ))}
      </dl>
      {toc && (
        <nav className="toc" aria-label="On this page">
          {toc.map(([id, l]) => (
            <a key={id} href={`#${id}`}>
              {l}
            </a>
          ))}
        </nav>
      )}
    </header>
  );
}

export function Keys({ items }: { items: { v: ReactNode; l: ReactNode; s?: ReactNode }[] }) {
  return (
    <div className="keys">
      {items.map((it, i) => (
        <div className="key" key={i}>
          <div className="v">{it.v}</div>
          <div className="l">{it.l}</div>
          {it.s && <div className="s">{it.s}</div>}
        </div>
      ))}
    </div>
  );
}

export function Note({ title, chip, children }: { title?: string; chip?: Status; children: ReactNode }) {
  return (
    <aside className="note prose">
      {(title || chip) && (
        <div className="h">
          {chip && <Chip s={chip} />}
          {title}
        </div>
      )}
      {children}
    </aside>
  );
}

export function Figure({
  n,
  title,
  sub,
  children,
  caption,
  table,
}: {
  n: string;
  title: string;
  sub?: ReactNode;
  children: ReactNode;
  caption?: ReactNode;
  table?: ReactNode;
}) {
  return (
    <figure className="fig">
      <div className="fig-head">
        <div className="t">
          <span className="fn">Figure {n}.</span>
          {title}
        </div>
        {sub && <div className="sub">{sub}</div>}
      </div>
      {children}
      {caption && <figcaption>{caption}</figcaption>}
      {table && (
        <details className="tbl">
          <summary>Show the numbers</summary>
          {table}
        </details>
      )}
    </figure>
  );
}

export function DataTable({
  head,
  rows,
  right = [],
  hi = [],
}: {
  head: ReactNode[];
  rows: ReactNode[][];
  right?: number[];
  hi?: number[];
}) {
  return (
    <div className="table-wrap">
      <table className="data">
        <thead>
          <tr>
            {head.map((h, i) => (
              <th key={i} className={right.includes(i) ? "r" : ""}>
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={i} className={hi.includes(i) ? "hi" : ""}>
              {r.map((c, j) => (
                <td key={j} className={right.includes(j) ? "r" : ""}>
                  {c}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// ------------------------------------------------------------ dot plot with intervals

export type DotRow = {
  label: ReactNode;
  title?: string; // hover text
  v: number;
  lo?: number | null;
  hi?: number | null;
  b?: number; // second value (dumbbell): drawn muted, linked to v
  val?: ReactNode;
  tone?: "hi" | "dim";
  hollow?: boolean;
  group?: string;
};

export function DotPlot({
  rows,
  domain,
  ticks,
  axis,
  zero,
  band,
  fmt = (x: number) => String(x),
}: {
  rows: DotRow[];
  domain: [number, number];
  ticks: number[];
  axis: string;
  zero?: boolean;
  band?: [number, number];
  fmt?: (x: number) => string;
}) {
  const [d0, d1] = domain;
  const x = (v: number) => `${(((Math.min(d1, Math.max(d0, v)) - d0) / (d1 - d0)) * 100).toFixed(2)}%`;
  const w = (a: number, b: number) => `${(((Math.min(d1, b) - Math.max(d0, a)) / (d1 - d0)) * 100).toFixed(2)}%`;
  let lastGroup: string | undefined;
  return (
    <div className="dp" role="img" aria-label={axis}>
      {rows.map((r, i) => {
        const g = r.group !== lastGroup ? r.group : undefined;
        lastGroup = r.group;
        return (
          <div key={i}>
            {g && <div className="dp-group">{g}</div>}
            <div className={`dp-row ${r.tone ?? ""}`} title={r.title}>
              <div className="dp-label">{r.label}</div>
              <div className="dp-track">
                {band && <div className="dp-band" style={{ left: x(band[0]), width: w(band[0], band[1]) }} />}
                {ticks.map((t) => (
                  <div key={t} className="dp-grid" style={{ left: x(t) }} />
                ))}
                {zero && <div className="dp-zero" style={{ left: x(0) }} />}
                {r.b !== undefined && (
                  <>
                    <div className="dp-link" style={{ left: x(Math.min(r.v, r.b)), width: w(Math.min(r.v, r.b), Math.max(r.v, r.b)) }} />
                    <div className="dp-dot b" style={{ left: x(r.b) }} />
                  </>
                )}
                {r.lo != null && r.hi != null && (
                  <div className="dp-ci" style={{ left: x(r.lo), width: w(r.lo, r.hi) }} />
                )}
                <div className={`dp-dot ${r.hollow ? "hollow" : ""}`} style={{ left: x(r.v) }} />
              </div>
              <div className="dp-val">{r.val ?? fmt(r.v)}</div>
            </div>
          </div>
        );
      })}
      <div className="dp-axis" aria-hidden="true">
        <div />
        <div className="ticks">
          {ticks.map((t) => (
            <span key={t} style={{ left: x(t) }}>
              {fmt(t)}
            </span>
          ))}
        </div>
        <div />
        <div className="lab">{axis}</div>
      </div>
    </div>
  );
}

export function Legend({ items }: { items: { c: string; l: string; kind?: "dot" | "bar" | "ring" }[] }) {
  return (
    <div className="legend">
      {items.map((it) => (
        <span key={it.l}>
          <i
            className={it.kind === "bar" ? "bar" : ""}
            style={
              it.kind === "ring"
                ? { border: `2px solid ${it.c}`, background: "var(--bg)" }
                : it.kind === "bar"
                  ? {}
                  : { background: it.c }
            }
          />
          {it.l}
        </span>
      ))}
    </div>
  );
}

export function More({ href, children }: { href: string; children: ReactNode }) {
  return <Link href={href}>{children}</Link>;
}
