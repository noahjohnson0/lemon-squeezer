// VRAM footprint per model (approx, q4 quant) so the recommender can answer
// "best open model that fits N GB". Quality is read live from runs.jsonl (cloud,
// venue-independent); fit is this lookup. vramQ4GB is the whole-model size at ~4-bit
// (MoE counts ALL experts, since they must be resident). null = cloud-scale, does
// not fit any consumer GPU. ollamaTag is the local pull when one exists.
// These are estimates; refine against `ollama list` sizes.

// slug = OpenRouter model id (its model-card URL is openrouter.ai/<slug>).
// blurb = one-line "what is this": maker, family, role. Authoritative detail
// (context, license, exact params, dates) lives on the linked card.
export type ModelMeta = { vramQ4GB: number | null; ollamaTag?: string; note?: string; slug?: string; blurb?: string };

export const MODEL_META: Record<string, ModelMeta> = {
  // local-runnable (have a realistic consumer-GPU footprint)
  "llama-3.1-8b":      { vramQ4GB: 5,    note: "8B dense", slug: "meta-llama/llama-3.1-8b-instruct", blurb: "Meta Llama 3.1, the small 8B dense generalist - weak as a coding agent on its own, very harness-sensitive." },
  "qwen3-14b":         { vramQ4GB: 9,    note: "14B dense", slug: "qwen/qwen3-14b", blurb: "Alibaba Qwen3 14B dense generalist; a comfortable 12 GB local pick." },
  "mistral-small-3.2": { vramQ4GB: 14,   note: "24B dense", slug: "mistralai/mistral-small-3.2-24b-instruct", blurb: "Mistral Small 3.2, a 24B dense generalist." },
  "codestral-2508":    { vramQ4GB: 13,   note: "22B dense, coding", slug: "mistralai/codestral-2508", blurb: "Mistral Codestral (Aug 2025), a ~22B dense coding specialist." },
  "devstral-2512":     { vramQ4GB: 14,   note: "24B dense, agentic", slug: "mistralai/devstral-2512", blurb: "Mistral Devstral (Dec 2025), a 24B dense model tuned for agentic software tasks." },
  "gpt-oss-20b":       { vramQ4GB: 14,   ollamaTag: "gpt-oss:20b", note: "20B MoE", slug: "openai/gpt-oss-20b", blurb: "OpenAI's open-weight gpt-oss 20B MoE - the small sibling of gpt-oss-120b." },
  "qwen3-32b":         { vramQ4GB: 20,   note: "32B dense", slug: "qwen/qwen3-32b", blurb: "Alibaba Qwen3 32B dense generalist." },
  "qwen3-coder-30b":   { vramQ4GB: 19,   ollamaTag: "qwen3-coder:30b", note: "30B-a3b MoE", slug: "qwen/qwen3-coder-30b-a3b-instruct", blurb: "Qwen3-Coder 30B (3B active MoE), coding-specialized and local-runnable - the strongest agent that fits a 24 GB card." },
  "llama-3.3-70b":     { vramQ4GB: 40,   note: "70B dense", slug: "meta-llama/llama-3.3-70b-instruct", blurb: "Meta Llama 3.3 70B dense generalist." },
  "nemotron-3-120b":   { vramQ4GB: 70,   note: "120B-a12b MoE", slug: "nvidia/nemotron-3-super-120b-a12b", blurb: "NVIDIA Nemotron-3 Super, a 120B (12B active) MoE generalist." },
  "gpt-oss-120b":      { vramQ4GB: 63,   note: "120B MoE", slug: "openai/gpt-oss-120b", blurb: "OpenAI's open-weight gpt-oss 120B MoE - high quality and very cheap to serve; the value pick on this benchmark." },
  "qwen3-235b-2507":   { vramQ4GB: 140,  note: "235B-a22b MoE", slug: "qwen/qwen3-235b-a22b-2507", blurb: "Qwen3 235B (22B active) MoE flagship (2507 release)." },

  // cloud-scale (do not fit any consumer GPU)
  "deepseek-v4-flash": { vramQ4GB: null, slug: "deepseek/deepseek-v4-flash", blurb: "DeepSeek V4 Flash - the fast, cheap tier of V4; near the top of this benchmark for a fraction of a cent per task." },
  "deepseek-v4-pro":   { vramQ4GB: null, slug: "deepseek/deepseek-v4-pro", blurb: "DeepSeek V4 Pro - the frontier-open generalist that tops this leaderboard." },
  "deepseek-v3.2":     { vramQ4GB: null, slug: "deepseek/deepseek-v3.2", blurb: "DeepSeek V3.2 generalist (the prior-gen flagship)." },
  "deepseek-r1":       { vramQ4GB: null, slug: "deepseek/deepseek-r1", blurb: "DeepSeek R1, a chain-of-thought reasoning model - strong at math/logic but underperforms at agentic coding here." },
  "qwen3-coder-480b":  { vramQ4GB: null, slug: "qwen/qwen3-coder", blurb: "Qwen3-Coder 480B MoE, Alibaba's flagship coding model." },
  "qwen3-coder-plus":  { vramQ4GB: null, slug: "qwen/qwen3-coder-plus", blurb: "Qwen3-Coder Plus, the hosted coding tier." },
  "qwen3-max":         { vramQ4GB: null, slug: "qwen/qwen3-max", blurb: "Alibaba Qwen3-Max, the large flagship generalist." },
  "kimi-k2.7-code":    { vramQ4GB: null, slug: "moonshotai/kimi-k2.7-code", blurb: "Moonshot Kimi K2.7 (coding variant), an agentic-coding model." },
  "kimi-k2-thinking":  { vramQ4GB: null, slug: "moonshotai/kimi-k2-thinking", blurb: "Moonshot Kimi K2 'thinking', the reasoning variant." },
  "glm-4.6":           { vramQ4GB: null, slug: "z-ai/glm-4.6", blurb: "Zhipu GLM-4.6 generalist." },
  "glm-4.7":           { vramQ4GB: null, slug: "z-ai/glm-4.7", blurb: "Zhipu GLM-4.7, a strong agentic/coding generalist." },
  "glm-5.1":           { vramQ4GB: null, slug: "z-ai/glm-5.1", blurb: "Zhipu GLM-5.1, the latest flagship - top-cluster on this benchmark." },
  "minimax-m2.7":      { vramQ4GB: null, slug: "minimax/minimax-m2.7", blurb: "MiniMax M2.7, an agentic generalist." },
  "minimax-m3":        { vramQ4GB: null, slug: "minimax/minimax-m3", blurb: "MiniMax M3, the latest agentic generalist." },
};

// Model-card URL for an arm label (OpenRouter page), or null if unknown / a mix.
export function modelCardUrl(label: string): string | null {
  const m = MODEL_META[label];
  return m?.slug ? `https://openrouter.ai/${m.slug}` : null;
}

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
