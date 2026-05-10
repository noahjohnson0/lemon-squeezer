"use client";
import { motion } from "framer-motion";
import { Run, colorForModel, unique } from "@/lib/data";

type ModelStats = {
  model: string;
  avgTemp: number;
  peakTemp: number;
  peakVramGB: number;
  avgPowerW: number;
  totalWh: number;
  runs: number;
};

function HBar({ value, max, color }: { value: number; max: number; color: string }) {
  const pct = max > 0 ? Math.min(100, (value / max) * 100) : 0;
  return (
    <div className="h-2 bg-[var(--border)] rounded overflow-hidden">
      <motion.div
        initial={{ width: 0 }}
        animate={{ width: `${pct}%` }}
        transition={{ duration: 0.6, ease: "easeOut" }}
        className="h-full"
        style={{ background: color, boxShadow: `0 0 8px ${color}80` }}
      />
    </div>
  );
}

export default function HardwarePanel({ runs }: { runs: Run[] }) {
  const tele = runs.filter((r) => r.telemetry && (r.telemetry.samples ?? 0) > 0);
  if (tele.length === 0) return null;

  const models = unique(tele.map((r) => r.model));
  const stats: ModelStats[] = models.map((m) => {
    const rs = tele.filter((r) => r.model === m);
    const t = rs.map((r) => r.telemetry!);
    const avg = (xs: (number | undefined)[]) => {
      const ns = xs.filter((x): x is number => Number.isFinite(x ?? NaN));
      return ns.length ? ns.reduce((s, x) => s + x, 0) / ns.length : 0;
    };
    const max = (xs: (number | undefined)[]) => {
      const ns = xs.filter((x): x is number => Number.isFinite(x ?? NaN));
      return ns.length ? Math.max(...ns) : 0;
    };
    return {
      model: m,
      avgTemp: avg(t.map((x) => x.gpu_temp_avg_c)),
      peakTemp: max(t.map((x) => x.gpu_temp_peak_c)),
      peakVramGB: max(t.map((x) => x.gpu_mem_peak_mb)) / 1024,
      avgPowerW: avg(t.map((x) => x.gpu_power_avg_w)),
      totalWh: rs.reduce(
        (s, r) =>
          s +
          ((r.telemetry?.gpu_power_avg_w ?? 0) * (r.wall_seconds ?? 0)) / 3600,
        0
      ),
      runs: rs.length,
    };
  });
  // Sort: most power-efficient first (lowest avgPowerW)
  stats.sort((a, b) => a.avgPowerW - b.avgPowerW);

  const maxTemp = Math.max(...stats.map((s) => s.peakTemp));
  const maxVram = Math.max(...stats.map((s) => s.peakVramGB));
  const maxPow = Math.max(...stats.map((s) => s.avgPowerW));

  return (
    <section className="max-w-7xl mx-auto px-6 mt-12">
      <div className="flex items-baseline gap-3 mb-2">
        <h2 className="text-xl font-semibold">Hardware telemetry</h2>
        <span className="chip">{tele.length} runs sampled</span>
      </div>
      <p className="text-[var(--muted)] text-sm max-w-3xl mb-4">
        Sampled every 1s during each run via <code>nvidia-smi</code> on the GPU host.
        Per-model averages — peak GPU temperature, peak VRAM, average power draw,
        and total energy used. Models that consistently push the GPU harder cost
        more electricity per token.
      </p>
      <div className="bg-[var(--panel)] border border-[var(--border)] rounded-xl p-4 overflow-x-auto">
        <table className="w-full text-xs">
          <thead className="text-[10px] uppercase tracking-wider text-[var(--muted)]">
            <tr>
              <th className="text-left pb-2">model</th>
              <th className="text-right pb-2 px-2">runs</th>
              <th className="text-right pb-2 px-2">peak °C</th>
              <th className="text-left pb-2 px-2 w-[120px]"></th>
              <th className="text-right pb-2 px-2">peak GB</th>
              <th className="text-left pb-2 px-2 w-[120px]"></th>
              <th className="text-right pb-2 px-2">avg W</th>
              <th className="text-left pb-2 px-2 w-[120px]"></th>
              <th className="text-right pb-2 px-2">total Wh</th>
            </tr>
          </thead>
          <tbody>
            {stats.map((s, i) => {
              const color = colorForModel(s.model, models);
              return (
                <motion.tr
                  key={s.model}
                  initial={{ opacity: 0, x: -8 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ duration: 0.4, delay: i * 0.04 }}
                  className="border-t border-[var(--border)]"
                >
                  <td className="py-2 font-mono text-[11px]">
                    <span
                      className="inline-block w-2 h-2 rounded-full mr-1.5"
                      style={{ background: color, boxShadow: `0 0 4px ${color}` }}
                    />
                    {s.model}
                  </td>
                  <td className="py-2 text-right text-[var(--muted)] px-2">{s.runs}</td>
                  <td className="py-2 text-right tabular-nums px-2">
                    {s.peakTemp.toFixed(0)}
                  </td>
                  <td className="py-2 px-2">
                    <HBar value={s.peakTemp} max={maxTemp} color="#ff7b72" />
                  </td>
                  <td className="py-2 text-right tabular-nums px-2">
                    {s.peakVramGB.toFixed(1)}
                  </td>
                  <td className="py-2 px-2">
                    <HBar value={s.peakVramGB} max={maxVram} color="#7ee787" />
                  </td>
                  <td className="py-2 text-right tabular-nums px-2">
                    {s.avgPowerW.toFixed(1)}
                  </td>
                  <td className="py-2 px-2">
                    <HBar value={s.avgPowerW} max={maxPow} color="#ffd33d" />
                  </td>
                  <td className="py-2 text-right tabular-nums px-2">
                    {s.totalWh.toFixed(2)}
                  </td>
                </motion.tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </section>
  );
}
