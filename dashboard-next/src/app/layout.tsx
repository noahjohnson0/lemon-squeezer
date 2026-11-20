import type { Metadata } from "next";
import { Source_Serif_4, IBM_Plex_Sans, IBM_Plex_Mono } from "next/font/google";
import "./globals.css";
import SiteHeader from "@/components/SiteHeader";
import { totals } from "@/lib/site-data";

const serif = Source_Serif_4({ subsets: ["latin"], variable: "--font-serif", display: "swap", axes: ["opsz"] });
const sans = IBM_Plex_Sans({ subsets: ["latin"], variable: "--font-sans", display: "swap", weight: ["400", "500", "600"] });
const mono = IBM_Plex_Mono({ subsets: ["latin"], variable: "--font-mono", display: "swap", weight: ["400", "500"] });

export const metadata: Metadata = {
  title: { default: "lemon-squeezer: an independent local-LLM lab", template: "%s · lemon-squeezer" },
  description:
    "Measured results on open-weight language models as agents: tool calling on a 128 GB workstation, coding agents across harnesses, cloud model comparisons and a 12 GB consumer GPU. Every number is computed from published run data.",
};

// Set the theme before first paint: ?theme=light|dark, then a saved choice, else the OS setting.
const THEME_SCRIPT = `(function(){try{var q=new URLSearchParams(location.search).get('theme');var t=q||localStorage.getItem('theme');if(t==='light'||t==='dark')document.documentElement.dataset.theme=t;}catch(e){}})();`;

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const t = totals();
  return (
    <html lang="en" className={`${serif.variable} ${sans.variable} ${mono.variable}`} suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_SCRIPT }} />
      </head>
      <body>
        <SiteHeader />
        <main className="page">{children}</main>
        <footer className="site-footer">
          <div className="bar">
            <div>
              lemon-squeezer publishes the measured results of an independent research program on open-weight models.
              <br />
              Built from {t.runs.toLocaleString("en-US")} coding-suite runs and {t.studioRows} tool-calling task rows. MIT licensed.
            </div>
            <div>
              <a href="https://github.com/noahjohnson0/lemon-squeezer">Source and data on GitHub</a>
            </div>
          </div>
        </footer>
      </body>
    </html>
  );
}
