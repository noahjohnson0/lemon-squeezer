"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";

const NAV = [
  { href: "/", label: "Findings" },
  { href: "/studies/", label: "Studies" },
  { href: "/methods/", label: "Methods" },
  { href: "/data/", label: "Data" },
  { href: "/about/", label: "About" },
];

function toggleTheme() {
  const root = document.documentElement;
  const cur = root.dataset.theme ?? (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
  const next = cur === "dark" ? "light" : "dark";
  root.dataset.theme = next;
  try {
    localStorage.setItem("theme", next);
  } catch {}
}

export default function SiteHeader() {
  const path = usePathname() || "/";
  const norm = (p: string) => (p.endsWith("/") ? p : p + "/");
  const active = (href: string) => (href === "/" ? norm(path) === "/" : norm(path).startsWith(href));
  return (
    <header className="site-header">
      <div className="bar">
        <Link href="/" className="wordmark">
          <span className="dot" aria-hidden="true" />
          lemon-squeezer <span className="lab">· a local-LLM lab</span>
        </Link>
        <nav className="nav" aria-label="Site">
          {NAV.map((n) => (
            <Link key={n.href} href={n.href} aria-current={active(n.href) ? "page" : undefined}>
              {n.label}
            </Link>
          ))}
          <button className="theme-btn" onClick={toggleTheme} aria-label="Toggle light or dark theme" type="button">
            ◐
          </button>
        </nav>
      </div>
    </header>
  );
}
