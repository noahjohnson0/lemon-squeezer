"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";

const LINKS = [
  { href: "/", label: "Overview" },
  { href: "/cloud", label: "Cloud" },
  { href: "/orchestration", label: "Orchestration" },
  { href: "/showcase", label: "Showcase" },
  { href: "/bench", label: "RAG eval" },
];

export default function SiteNav() {
  const path = usePathname();
  const isActive = (href: string) =>
    href === "/" ? path === "/" : path.startsWith(href);

  // "live" = newest run is within 15 min of now (loadRuns stamps it globally).
  const [live, setLive] = useState(false);
  useEffect(() => {
    const tick = () => {
      const ms = (globalThis as Record<string, unknown>).__lemonLastRunMs as number | undefined;
      setLive(!!ms && Date.now() - ms < 15 * 60 * 1000);
    };
    tick();
    const id = setInterval(tick, 5000);
    return () => clearInterval(id);
  }, []);

  return (
    <header className="sticky top-0 z-40 backdrop-blur-md bg-[color-mix(in_srgb,var(--bg)_72%,transparent)] border-b border-[var(--border)]">
      <nav className="max-w-7xl mx-auto px-6 h-12 flex items-center gap-5">
        <Link href="/" className="flex items-center gap-2 font-semibold tracking-tight">
          <span className="text-lg">🍋</span>
          <span className="hidden sm:inline">lemon<span className="text-[var(--accent)]">·</span>squeezer</span>
        </Link>
        <div className="flex items-center gap-1 text-sm">
          {LINKS.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              className={`px-2.5 py-1 rounded-md transition-colors ${
                isActive(l.href)
                  ? "text-[var(--accent)] bg-[color-mix(in_srgb,var(--accent)_10%,transparent)]"
                  : "text-[var(--muted)] hover:text-[var(--text)]"
              }`}
            >
              {l.label}
            </Link>
          ))}
        </div>
        <div className="ml-auto flex items-center gap-3">
          <span className="flex items-center gap-1.5 text-xs" title={live ? "a run finished in the last 15 min" : "no recent runs"}>
            <span className={live ? "dot-live" : "dot-idle"} />
            <span className={live ? "text-[var(--good)]" : "text-[var(--faint)]"}>{live ? "live" : "idle"}</span>
          </span>
          <a
            href="https://github.com/noahjohnson0/lemon-squeezer#how-it-works"
            className="text-xs text-[var(--muted)] hover:text-[var(--accent)] transition-colors hidden sm:inline"
          >
            Methodology
          </a>
          <a
            href="https://github.com/noahjohnson0/lemon-squeezer"
            className="text-xs text-[var(--muted)] hover:text-[var(--accent)] transition-colors"
          >
            GitHub ↗
          </a>
        </div>
      </nav>
    </header>
  );
}
