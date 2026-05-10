import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "🍋 Lemon Squeezer — local-LLM coding agent benchmarks",
  description:
    "Reproducible benchmarks for local-LLM coding agents on consumer GPUs. Get the absolute most juice possible from a local model.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
