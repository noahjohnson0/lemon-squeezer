import type { Metadata } from "next";
import "./globals.css";
import SiteNav from "@/components/SiteNav";

export const metadata: Metadata = {
  title: "lemon-squeezer — how much can you squeeze out of an LLM?",
  description:
    "Open research into getting the most out of LLMs as coding agents: which model × harness × config × venue (local GPU or open weights in the cloud) actually finishes the work. Reproducible, rubric-scored.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full flex flex-col">
        <SiteNav />
        {children}
      </body>
    </html>
  );
}
