"use client";
import { motion } from "framer-motion";
import Link from "next/link";

type Props = { runCount: number };

export default function Hero({ runCount }: Props) {
  return (
    <section className="relative overflow-hidden">
      {/* Background gradient orbs */}
      <div className="absolute inset-0 -z-10 overflow-hidden">
        <motion.div
          className="absolute -top-40 -left-40 w-[600px] h-[600px] rounded-full"
          style={{
            background:
              "radial-gradient(circle, rgba(255,209,102,0.18) 0%, rgba(255,159,28,0.06) 40%, transparent 70%)",
            filter: "blur(40px)",
          }}
          animate={{ x: [0, 60, 0], y: [0, -40, 0], scale: [1, 1.1, 1] }}
          transition={{ duration: 22, repeat: Infinity, ease: "easeInOut" }}
        />
        <motion.div
          className="absolute -bottom-40 -right-40 w-[500px] h-[500px] rounded-full"
          style={{
            background:
              "radial-gradient(circle, rgba(210,168,255,0.18) 0%, rgba(121,192,255,0.06) 40%, transparent 70%)",
            filter: "blur(40px)",
          }}
          animate={{ x: [0, -50, 0], y: [0, 30, 0], scale: [1, 1.15, 1] }}
          transition={{ duration: 28, repeat: Infinity, ease: "easeInOut" }}
        />
      </div>

      <div className="max-w-7xl mx-auto px-6 pt-10 pb-6">
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          className="flex items-center justify-between gap-3 mb-2 flex-wrap"
        >
          <div className="flex items-center gap-3">
            <span className="text-3xl">🍋</span>
            <span className="text-[10px] uppercase tracking-[0.2em] text-[var(--muted)]">
              local-llm coding agent benchmarks
            </span>
          </div>
          <div className="flex items-baseline gap-4 text-[var(--muted)] text-xs uppercase tracking-wider">
            <Link href="/bench" className="hover:text-[var(--accent)] tracking-wider normal-case">
              📚 benchmarks →
            </Link>
            <div className="flex items-baseline gap-2">
              <span className="text-[var(--accent)] font-bold tabular-nums text-base normal-case tracking-normal">
                {runCount.toLocaleString()}
              </span>
              <span>runs · live</span>
            </div>
          </div>
        </motion.div>

        <motion.h1
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.05 }}
          className="text-3xl md:text-5xl font-bold tracking-tight gradient-text leading-[1.05]"
        >
          The Lemon Squeezer
        </motion.h1>

        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.6, delay: 0.15 }}
          className="text-[var(--muted)] italic text-base mt-2 max-w-3xl"
        >
          Get the absolute most juice possible out of a local LLM. Reproducible benchmarks for
          coding agents across heterogeneous hardware — same prompts and rubrics, different
          models, harnesses, configs, and machines.
        </motion.p>
      </div>
    </section>
  );
}
