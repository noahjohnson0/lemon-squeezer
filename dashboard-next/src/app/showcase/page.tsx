"use client";
import { useEffect, useState } from "react";
import ModelBadge from "@/components/ModelBadge";

type Item = { model: string; score: number | string; cost?: number; wall?: number; bytes: number; file: string };
type Manifest = { evals: Record<string, Item[]>; prompts?: Record<string, string> };

const TASKS: Record<string, { title: string; blurb: string }> = {
  "web-snake": { title: "Snake game", blurb: "A playable Snake game in one self-contained HTML file - canvas, keyboard, score, game over." },
  "web-3d-scene": { title: "3D scene", blurb: "An interactive lit, rotating 3D scene using three.js with mouse-drag orbit." },
  "web-particles": { title: "Particle toy", blurb: "An animated canvas particle system that reacts to the mouse." },
  "web-landing": { title: "Landing page", blurb: "A responsive product landing page: nav, hero, feature cards, footer." },
  "web-calculator": { title: "Calculator", blurb: "A working calculator web app with correct arithmetic and keyboard input." },
};

const LADDER_NOTE: Record<string, string> = {
  "llama-3.1-8b": "8B - tiny",
  "qwen3-coder-30b": "30B - fits a 24 GB GPU",
  "gpt-oss-120b": "120B open - cheap cloud",
  "deepseek-v4-pro": "top open model",
  "claude-opus-4.8": "closed flagship",
};

// Live thumbnail: render each artifact at a large logical viewport, then scale it
// down to fit the card so the WHOLE thing is visible with no scrollbar.
const LOGICAL_W = 1080, LOGICAL_H = 860, DISPLAY_W = 360;
const SCALE = DISPLAY_W / LOGICAL_W;
const DISPLAY_H = Math.round(LOGICAL_H * SCALE);

export default function ShowcasePage() {
  const [m, setM] = useState<Manifest | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [openPrompt, setOpenPrompt] = useState<Record<string, boolean>>({});
  useEffect(() => {
    fetch("../showcase.json")
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(`showcase.json ${r.status}`))))
      .then(setM)
      .catch((e) => setErr(String(e)));
  }, []);

  const evals = m ? Object.keys(m.evals) : [];

  return (
    <main>
      <section className="max-w-7xl mx-auto px-6 pt-10 pb-4">
        <span className="text-[10px] uppercase tracking-[0.25em] text-[var(--muted)]">showcase · what each tier actually builds</span>
        <h1 className="text-3xl md:text-5xl font-bold tracking-tight gradient-text leading-[1.04] mt-2">
          Don&apos;t take our word for it - play it.
        </h1>
        <p className="text-[var(--muted)] text-base mt-3 max-w-3xl leading-relaxed">
          We asked models across the capability ladder - from a tiny 8B you can run on a laptop to a closed frontier
          flagship - for a single self-contained <code className="text-xs text-[var(--text)]">index.html</code>: a game,
          a 3D scene, a toy, a page, a calculator. Below is <b className="text-[var(--text)]">exactly what each one
          produced</b>, the whole thing scaled to fit. Same prompt, same agent - the difference is the model.
        </p>
        <p className="text-xs text-[var(--faint)] mt-2">Thumbnails are live, sandboxed, scaled to fit (no scrolling). Hit <b>open</b> to play one full size.</p>
      </section>

      {err && <div className="max-w-7xl mx-auto px-6 text-[var(--bad)] text-sm">Couldn&apos;t load showcase: {err}</div>}
      {!m && !err && <div className="max-w-7xl mx-auto px-6 text-[var(--muted)] text-sm">Loading artifacts...</div>}

      {evals.map((ev) => {
        const meta = TASKS[ev] ?? { title: ev, blurb: "" };
        const items = m!.evals[ev];
        const prompt = m!.prompts?.[ev];
        const showP = !!openPrompt[ev];
        return (
          <section key={ev} className="max-w-7xl mx-auto px-6 mt-10">
            <div className="flex items-baseline gap-3 mb-1 flex-wrap">
              <h2 className="text-xl font-semibold">{meta.title}</h2>
              <span className="chip">{items.length} models</span>
              {prompt && (
                <button onClick={() => setOpenPrompt((s) => ({ ...s, [ev]: !s[ev] }))}
                        className="text-xs text-[var(--accent)] hover:underline">
                  {showP ? "hide prompt" : "view prompt ↓"}
                </button>
              )}
            </div>
            <p className="text-[var(--muted)] text-sm max-w-3xl mb-3">{meta.blurb}</p>
            {prompt && showP && (
              <pre className="text-[11px] leading-relaxed bg-[var(--panel)] border border-[var(--border)] rounded-lg p-4 mb-4 whitespace-pre-wrap max-w-3xl text-[var(--muted)] overflow-x-auto">
                {prompt}
              </pre>
            )}
            <div className="flex gap-4 overflow-x-auto pb-3">
              {items.map((it) => (
                <div key={it.model} className="flex-none" style={{ width: DISPLAY_W }}>
                  <div className="flex items-center justify-between gap-2 mb-1">
                    <ModelBadge model={it.model} cost={it.cost} className="text-xs min-w-0" />
                    <a href={`../${it.file}`} target="_blank" rel="noopener noreferrer"
                       className="text-[10px] text-[var(--muted)] hover:text-[var(--accent)] whitespace-nowrap">open ↗</a>
                  </div>
                  <div className="text-[10px] text-[var(--faint)] mb-1.5 flex justify-between">
                    <span>{LADDER_NOTE[it.model] ?? ""}</span>
                    <span>built {typeof it.score === "number" ? `${it.score}%` : it.score} · {Math.round(it.bytes / 1024)} KB</span>
                  </div>
                  {/* scaled live thumbnail - whole artifact, no scroll */}
                  <div className="rounded-lg overflow-hidden border border-[var(--border)] bg-white"
                       style={{ width: DISPLAY_W, height: DISPLAY_H }}>
                    <iframe
                      src={`../${it.file}`}
                      title={`${it.model} - ${meta.title}`}
                      sandbox="allow-scripts allow-pointer-lock"
                      loading="lazy"
                      scrolling="no"
                      style={{ width: LOGICAL_W, height: LOGICAL_H, border: 0, transform: `scale(${SCALE})`, transformOrigin: "top left" }}
                    />
                  </div>
                </div>
              ))}
            </div>
          </section>
        );
      })}

      <footer className="max-w-7xl mx-auto px-6 mt-16 mb-8 pt-6 border-t border-[var(--border)] text-xs text-[var(--muted)]">
        source:{" "}
        <a href="https://github.com/noahjohnson0/lemon-squeezer" className="text-[var(--accent)] hover:underline">
          github.com/noahjohnson0/lemon-squeezer
        </a>
      </footer>
    </main>
  );
}
