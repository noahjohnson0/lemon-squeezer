"use client";
import { motion } from "framer-motion";

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

      <div className="max-w-7xl mx-auto px-6 pt-16 pb-10">
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7 }}
          className="flex items-center gap-3 mb-3"
        >
          <span className="text-4xl">🍋</span>
          <span className="text-xs uppercase tracking-[0.2em] text-[var(--muted)]">
            local-llm coding agent benchmarks
          </span>
        </motion.div>

        <motion.h1
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.05 }}
          className="text-5xl md:text-6xl font-bold tracking-tight gradient-text leading-[1.05]"
        >
          The Lemon Squeezer
        </motion.h1>

        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.7, delay: 0.2 }}
          className="text-[var(--muted)] italic text-xl mt-3 mb-6"
        >
          Get the absolute most juice possible out of a local LLM.
        </motion.p>

        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.7, delay: 0.3 }}
          className="max-w-2xl text-base text-[var(--text)]/85 leading-relaxed"
        >
          Reproducible benchmarks for local-LLM coding agents across heterogeneous hardware
          — RTX 4070, M4 Max, anything you point an Ollama at. Same prompts and rubrics,
          different harnesses, configs, models, and machines. The premise: cloud benchmarks
          tell you almost nothing about whether a model{" "}
          <span className="text-[var(--accent)]">on hardware you actually own</span> can
          finish a real-world task.
        </motion.p>

        <motion.div
          initial={{ opacity: 0, scale: 0.96 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.6, delay: 0.5 }}
          className="mt-8 flex items-baseline gap-3"
        >
          <span className="text-7xl md:text-8xl font-bold tabular-nums tracking-tight gradient-text">
            {runCount.toLocaleString()}
          </span>
          <span className="text-[var(--muted)] text-sm uppercase tracking-[0.15em]">
            runs captured · live
          </span>
        </motion.div>
      </div>
    </section>
  );
}
