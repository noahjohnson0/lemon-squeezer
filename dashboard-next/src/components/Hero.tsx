"use client";
import { motion } from "framer-motion";

type Props = { runCount: number };

export default function Hero({ runCount }: Props) {
  return (
    <section className="relative overflow-hidden">
      {/* Background gradient orbs (themed lemon-lime / mint) */}
      <div className="absolute inset-0 -z-10 overflow-hidden">
        <motion.div
          className="absolute -top-40 -left-40 w-[600px] h-[600px] rounded-full"
          style={{
            background:
              "radial-gradient(circle, rgba(216,232,74,0.16) 0%, rgba(216,232,74,0.05) 40%, transparent 70%)",
            filter: "blur(40px)",
          }}
          animate={{ x: [0, 60, 0], y: [0, -40, 0], scale: [1, 1.1, 1] }}
          transition={{ duration: 22, repeat: Infinity, ease: "easeInOut" }}
        />
        <motion.div
          className="absolute -bottom-40 -right-40 w-[500px] h-[500px] rounded-full"
          style={{
            background:
              "radial-gradient(circle, rgba(126,224,184,0.16) 0%, rgba(121,192,255,0.05) 40%, transparent 70%)",
            filter: "blur(40px)",
          }}
          animate={{ x: [0, -50, 0], y: [0, 30, 0], scale: [1, 1.15, 1] }}
          transition={{ duration: 28, repeat: Infinity, ease: "easeInOut" }}
        />
      </div>

      <div className="max-w-7xl mx-auto px-6 pt-12 pb-7">
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          className="flex items-center justify-between gap-3 mb-3 flex-wrap"
        >
          <span className="text-[10px] uppercase tracking-[0.25em] text-[var(--muted)]">
            open research · squeezing the most out of LLMs
          </span>
          <div className="flex items-baseline gap-2 text-[var(--muted)] text-xs uppercase tracking-wider">
            <span className="text-[var(--accent)] font-bold tabular-nums text-base normal-case tracking-normal">
              {runCount.toLocaleString()}
            </span>
            <span>scored runs · live</span>
          </div>
        </motion.div>

        <motion.h1
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.05 }}
          className="text-4xl md:text-6xl font-bold tracking-tight gradient-text leading-[1.03]"
        >
          How much can you squeeze<br className="hidden md:block" /> out of an LLM?
        </motion.h1>

        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.6, delay: 0.15 }}
          className="text-[var(--muted)] text-base md:text-lg mt-4 max-w-3xl leading-relaxed"
        >
          A reproducible study of what actually makes an LLM <em className="text-[var(--text)] not-italic font-medium">finish real coding work</em> —
          holding the prompts and rubrics fixed while varying the four things you control:
          <span className="text-[var(--text)]"> model</span>,
          <span className="text-[var(--text)]"> harness</span>,
          <span className="text-[var(--text)]"> config</span>, and
          <span className="text-[var(--text)]"> venue</span> (a single local GPU, or open weights rented in the cloud).
          Every score comes from running the produced code, not vibes.
        </motion.p>

        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.6, delay: 0.25 }}
          className="flex flex-wrap gap-2 mt-5 text-xs"
        >
          {[
            "harness often beats model",
            "mixes rescue weak models",
            "reasoning ≠ coding",
            "a 4070 gets ~97%",
          ].map((t) => (
            <span key={t} className="chip">{t}</span>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
