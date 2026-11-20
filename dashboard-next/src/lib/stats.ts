// Small, dependency-free statistics used at build time. Everything is seeded, so a rebuild
// from the same data prints the same intervals.

export const BOOT_B = 2000;
export const BOOT_SEED = 1234;

// mulberry32: tiny seeded PRNG
export function rng(seed = BOOT_SEED) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export const mean = (a: number[]) => (a.length ? a.reduce((s, x) => s + x, 0) / a.length : 0);

export function median(a: number[]) {
  if (!a.length) return 0;
  const s = [...a].sort((x, y) => x - y);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}

// 95% percentile bootstrap of the mean (resample the given units with replacement).
// Units are per-eval means (cluster bootstrap) or per-cell paired differences.
export function bootMeanCI(units: number[], b = BOOT_B, seed = BOOT_SEED): [number, number] | null {
  const k = units.length;
  if (k < 2) return null;
  const r = rng(seed);
  const s: number[] = [];
  for (let i = 0; i < b; i++) {
    let t = 0;
    for (let j = 0; j < k; j++) t += units[Math.floor(r() * k)];
    s.push(t / k);
  }
  s.sort((x, y) => x - y);
  return [s[Math.floor(0.025 * b)], s[Math.min(b - 1, Math.floor(0.975 * b))]];
}

// Wilson 95% interval for k of n, as fractions.
export function wilson(k: number, n: number, z = 1.96): [number, number] {
  if (!n) return [0, 1];
  const p = k / n;
  const d = 1 + (z * z) / n;
  const c = (p + (z * z) / (2 * n)) / d;
  const h = (z * Math.sqrt((p * (1 - p)) / n + (z * z) / (4 * n * n))) / d;
  return [Math.max(0, c - h), Math.min(1, c + h)];
}

export const round = (x: number, d = 1) => Math.round(x * 10 ** d) / 10 ** d;
