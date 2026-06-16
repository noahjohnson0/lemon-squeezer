"use client";
import { MODEL_META, modelCardUrl, vramLabel } from "@/lib/modelMeta";

const fmtCost = (c: number) => (c >= 0.01 ? `$${c.toFixed(3)}` : `$${c.toFixed(5)}`);

// One consistent way to show a model anywhere on the site: name links to its
// model card, with VRAM-to-run and (optionally) cost/task always attached, and the
// blurb on hover. Use this instead of bare model strings so "what does it cost /
// can I run it" is always one glance away.
export default function ModelBadge({
  model,
  cost,
  className = "",
}: {
  model: string;
  cost?: number | null;
  className?: string;
}) {
  const card = modelCardUrl(model);
  const vram = vramLabel(model);
  const meta = MODEL_META[model];
  return (
    <span className={`inline-flex items-center gap-1.5 flex-wrap ${className}`} title={meta?.blurb || model}>
      {card ? (
        <a href={card} target="_blank" rel="noopener noreferrer" className="font-mono text-[var(--accent)] hover:underline">
          {model} ↗
        </a>
      ) : (
        <span className="font-mono text-[var(--text)]">{model}</span>
      )}
      {vram && <span className="chip" title="VRAM to run locally at q4, or 'cloud' if too big for a consumer GPU">{vram}</span>}
      {cost != null && cost > 0 && <span className="chip" title="cost per task">{fmtCost(cost)}/task</span>}
    </span>
  );
}
