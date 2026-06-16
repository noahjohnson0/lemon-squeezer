"use client";
import ModelBadge from "@/components/ModelBadge";

// The actual orchestration run that built the /orchestration tab: one Claude
// conducting three coding agents in parallel. Each row shows the AGENT (the
// harness/CLI), the MODEL it ran, what it built, and what that leg actually cost -
// the harness x model split this whole project is about.
const roster = [
  { agent: "Claude Code", model: "claude-opus-4.8", role: "conductor", built: "planned the work, wrote the page, integrated the pieces, verified the build", cost: "the conductor" },
  { agent: "codex", model: "gpt-5.5", role: "worker", built: "the animated orchestration flow diagram (278 lines)", cost: "ChatGPT sub" },
  { agent: "kimi (via squeezer)", model: "kimi-k2.7-code", role: "worker", built: "the orchestration patterns data (JSON)", cost: "$0.011 · 23k/2.7k tok" },
  { agent: "aider", model: "deepseek-v4-flash", role: "worker", built: "this conductor panel", cost: "$0.0002" },
];

export default function ConductorPanel() {
  const conductor = roster.find((m) => m.role === "conductor")!;
  const workers = roster.filter((m) => m.role === "worker");

  return (
    <div className="p-6 space-y-5" style={{ background: "var(--panel)", color: "var(--text)", borderRadius: "0.9rem", border: "1px solid var(--border)" }}>
      <h2 className="text-xl font-semibold">Built by orchestration</h2>

      {/* Conductor */}
      <div className="relative flex items-start gap-4 p-4" style={{ background: "var(--accent)", color: "#0b0e14", borderRadius: "0.9rem" }}>
        <span className="relative flex h-3.5 w-3.5 mt-1">
          <span className="animate-ping absolute inline-flex h-full w-full rounded-full opacity-60" style={{ background: "#0b0e14" }} />
          <span className="relative inline-flex rounded-full h-3.5 w-3.5" style={{ background: "#0b0e14" }} />
        </span>
        <div className="min-w-0">
          <p className="font-bold text-lg leading-tight">{conductor.agent} <span className="font-normal text-sm opacity-70">conductor · {conductor.model}</span></p>
          <p className="text-sm opacity-80 mt-0.5">{conductor.built}</p>
        </div>
      </div>

      {/* Workers */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {workers.map((w) => (
          <div key={w.agent} className="p-4 flex flex-col gap-2" style={{ background: "var(--panel-2)", borderRadius: "0.9rem", border: "1px solid var(--border)" }}>
            <p className="font-semibold">{w.agent}</p>
            <ModelBadge model={w.model} className="text-xs" />
            <p className="text-sm text-[var(--muted)]">{w.built}</p>
            <p className="text-[11px] text-[var(--faint)] mt-auto pt-1">{w.cost}</p>
          </div>
        ))}
      </div>
      <p className="text-[11px] text-[var(--faint)]">
        Three agents in parallel, ~1.1c of API total, integration compiled on the first try. Wall-clock was the slowest single agent, not the sum.
      </p>
    </div>
  );
}
