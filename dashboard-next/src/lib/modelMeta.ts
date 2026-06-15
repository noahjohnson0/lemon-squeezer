// VRAM footprint per model (approx, q4 quant) so the recommender can answer
// "best open model that fits N GB". Quality is read live from runs.jsonl (cloud,
// venue-independent); fit is this lookup. vramQ4GB is the whole-model size at ~4-bit
// (MoE counts ALL experts, since they must be resident). null = cloud-scale, does
// not fit any consumer GPU. ollamaTag is the local pull when one exists.
// These are estimates; refine against `ollama list` sizes.

export type ModelMeta = { vramQ4GB: number | null; ollamaTag?: string; note?: string };

export const MODEL_META: Record<string, ModelMeta> = {
  // local-runnable (have a realistic consumer-GPU footprint)
  "llama-3.1-8b":      { vramQ4GB: 5,    note: "8B dense" },
  "qwen3-14b":         { vramQ4GB: 9,    note: "14B dense" },
  "mistral-small-3.2": { vramQ4GB: 14,   note: "24B dense" },
  "codestral-2508":    { vramQ4GB: 13,   note: "22B dense, coding" },
  "devstral-2512":     { vramQ4GB: 14,   note: "24B dense, agentic" },
  "gpt-oss-20b":       { vramQ4GB: 14,   ollamaTag: "gpt-oss:20b", note: "20B MoE" },
  "qwen3-32b":         { vramQ4GB: 20,   note: "32B dense" },
  "qwen3-coder-30b":   { vramQ4GB: 19,   ollamaTag: "qwen3-coder:30b", note: "30B-a3b MoE" },
  "llama-3.3-70b":     { vramQ4GB: 40,   note: "70B dense" },
  "nemotron-3-120b":   { vramQ4GB: 70,   note: "120B-a12b MoE" },
  "gpt-oss-120b":      { vramQ4GB: 63,   note: "120B MoE" },
  "qwen3-235b-2507":   { vramQ4GB: 140,  note: "235B-a22b MoE" },

  // cloud-scale (do not fit any consumer GPU)
  "deepseek-v4-flash": { vramQ4GB: null },
  "deepseek-v4-pro":   { vramQ4GB: null },
  "deepseek-v3.2":     { vramQ4GB: null },
  "deepseek-r1":       { vramQ4GB: null },
  "qwen3-coder-480b":  { vramQ4GB: null },
  "qwen3-coder-plus":  { vramQ4GB: null },
  "qwen3-max":         { vramQ4GB: null },
  "kimi-k2.7-code":    { vramQ4GB: null },
  "kimi-k2-thinking":  { vramQ4GB: null },
  "glm-4.6":           { vramQ4GB: null },
  "glm-4.7":           { vramQ4GB: null },
  "glm-5.1":           { vramQ4GB: null },
  "minimax-m2.7":      { vramQ4GB: null },
  "minimax-m3":        { vramQ4GB: null },
};

// Common GPUs -> VRAM (GB), for autodetect via the WebGL renderer string.
export const GPU_VRAM: Array<[RegExp, number]> = [
  [/RTX\s*40?90|RTX\s*3090|A6000|RTX\s*6000/i, 24],
  [/RTX\s*4080|RTX\s*3080\s*Ti|RTX\s*4070\s*Ti\s*Super/i, 16],
  [/RTX\s*4070|RTX\s*3060|RTX\s*4060\s*Ti\s*16|RTX\s*5070/i, 12],
  [/RTX\s*4060|RTX\s*3050|RTX\s*2060/i, 8],
  [/M\d+\s*Max/i, 48],
  [/M\d+\s*Pro/i, 24],
  [/M\d+/i, 16],
];

export const VRAM_TIERS = [8, 12, 16, 24, 48, 80];

export function detectVramTier(): number | null {
  if (typeof document === "undefined") return null;
  try {
    const gl = document.createElement("canvas").getContext("webgl");
    const ext = gl?.getExtension("WEBGL_debug_renderer_info");
    const r = ext ? (gl!.getParameter(ext.UNMASKED_RENDERER_WEBGL) as string) : "";
    if (!r) return null;
    for (const [re, gb] of GPU_VRAM) if (re.test(r)) return gb;
  } catch { /* blocked by browser */ }
  return null;
}
