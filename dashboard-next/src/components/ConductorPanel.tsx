"use client";

// Built by aider (driven by Claude via OpenRouter) in one shot for ~$0.0002.
// Conductor integrated it and fixed text contrast on the bright cards.
import React from "react";

const roster = [
  { name: "Claude", role: "conductor", note: "plans the work, integrates the pieces, verifies the build" },
  { name: "codex", role: "worker", note: "built the animated orchestration flow diagram" },
  { name: "kimi", role: "worker", note: "generated the orchestration patterns data" },
  { name: "aider", role: "worker", note: "built this conductor panel" },
] as const;

const ConductorPanel: React.FC = () => {
  const conductor = roster.find((m) => m.role === "conductor")!;
  const workers = roster.filter((m) => m.role === "worker");

  return (
    <div className="p-6 space-y-5" style={{ background: "var(--panel)", color: "var(--text)", borderRadius: "0.9rem", border: "1px solid var(--border)" }}>
      <h2 className="text-xl font-semibold">Built by orchestration</h2>

      {/* Conductor card - dark text on the bright accent for contrast */}
      <div className="relative flex items-center gap-4 p-4" style={{ background: "var(--accent)", color: "#0b0e14", borderRadius: "0.9rem" }}>
        <span className="relative flex h-3.5 w-3.5">
          <span className="animate-ping absolute inline-flex h-full w-full rounded-full opacity-60" style={{ background: "#0b0e14" }} />
          <span className="relative inline-flex rounded-full h-3.5 w-3.5" style={{ background: "#0b0e14" }} />
        </span>
        <div>
          <p className="font-bold text-lg">{conductor.name} <span className="font-normal text-sm opacity-70">conductor</span></p>
          <p className="text-sm opacity-80">{conductor.note}</p>
        </div>
      </div>

      {/* Workers - dark text on the bright sky tiles */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {workers.map((worker) => (
          <div key={worker.name} className="p-4" style={{ background: "var(--accent-3)", color: "#0b0e14", borderRadius: "0.9rem" }}>
            <p className="font-semibold font-mono">{worker.name}</p>
            <p className="text-sm opacity-80 mt-0.5">{worker.note}</p>
          </div>
        ))}
      </div>
    </div>
  );
};

export default ConductorPanel;
