"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";

const LINKS = [
  { href: "/", label: "Overview" },
  { href: "/cloud", label: "Cloud" },
  { href: "/bench", label: "RAG" },
];

export default function SiteNav() {
  const path = usePathname();
  const isActive = (href: string) =>
    href === "/" ? path === "/" : path.startsWith(href);

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
        <a
          href="https://github.com/noahjohnson0/lemon-squeezer"
          className="ml-auto text-xs text-[var(--muted)] hover:text-[var(--accent)] transition-colors"
        >
          GitHub ↗
        </a>
      </nav>
    </header>
  );
}
