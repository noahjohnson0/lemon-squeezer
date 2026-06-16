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

// Blurbs below are grounded in OpenRouter's own model descriptions (fetched, not
// guessed) so the post-cutoff models are described accurately. Refresh with the
// OpenRouter /models API if specs change.
export const MODEL_META: Record<string, ModelMeta> = {
  // local-runnable (have a realistic consumer-GPU footprint)
  "llama-3.1-8b":      { vramQ4GB: 5,    note: "8B dense", slug: "meta-llama/llama-3.1-8b-instruct", blurb: "Meta Llama 3.1 8B, the small, fast dense generalist - weak as a coding agent on its own and very harness-sensitive." },
  "qwen3-14b":         { vramQ4GB: 9,    note: "14.8B dense", slug: "qwen/qwen3-14b", blurb: "Alibaba Qwen3 14B, a dense 14.8B reasoning/dialogue model - a comfortable 12 GB local pick." },
  "mistral-small-3.2": { vramQ4GB: 14,   note: "24B dense", slug: "mistralai/mistral-small-3.2-24b-instruct", blurb: "Mistral Small 3.2, a 24B dense generalist tuned for instruction-following and function calling." },
  "codestral-2508":    { vramQ4GB: 13,   note: "~22B dense, coding", slug: "mistralai/codestral-2508", blurb: "Mistral Codestral (Aug 2025), a coding model tuned for low-latency fill-in-the-middle and high-frequency tasks." },
  "gpt-oss-20b":       { vramQ4GB: 14,   ollamaTag: "gpt-oss:20b", note: "21B MoE (3.6B active), Apache-2.0", slug: "openai/gpt-oss-20b", blurb: "OpenAI's open-weight gpt-oss-20b (21B MoE, 3.6B active, Apache-2.0) - the small sibling of gpt-oss-120b." },
  "qwen3-32b":         { vramQ4GB: 20,   note: "32.8B dense", slug: "qwen/qwen3-32b", blurb: "Alibaba Qwen3 32B, a dense 32.8B reasoning/dialogue model." },
  "qwen3-coder-30b":   { vramQ4GB: 19,   ollamaTag: "qwen3-coder:30b", note: "30.5B MoE (8/128 experts)", slug: "qwen/qwen3-coder-30b-a3b-instruct", blurb: "Qwen3-Coder 30B (30.5B MoE, 8 of 128 experts active), coding-specialized and local-runnable - the strongest agent that fits a 24 GB card." },
  "llama-3.3-70b":     { vramQ4GB: 40,   note: "70B dense", slug: "meta-llama/llama-3.3-70b-instruct", blurb: "Meta Llama 3.3 70B, an instruction-tuned dense multilingual generalist." },

  // cloud-scale (do not fit any consumer GPU)
  "devstral-2512":     { vramQ4GB: 62,   note: "123B dense, agentic", slug: "mistralai/devstral-2512", blurb: "Mistral Devstral 2 (Dec 2025), a 123B dense model specialized in agentic coding (256K context)." },
  "nemotron-3-120b":   { vramQ4GB: 70,   note: "120B hybrid MoE (12B active)", slug: "nvidia/nemotron-3-super-120b-a12b", blurb: "NVIDIA Nemotron 3 Super, a 120B hybrid MoE (12B active) built for compute-efficient multi-step tasks." },
  "gpt-oss-120b":      { vramQ4GB: 63,   note: "117B MoE", slug: "openai/gpt-oss-120b", blurb: "OpenAI's open-weight gpt-oss-120b (117B MoE) for high-reasoning agentic use - high quality and very cheap to serve; the value pick here." },
  "qwen3-235b-2507":   { vramQ4GB: 140,  note: "235B MoE (22B active)", slug: "qwen/qwen3-235b-a22b-2507", blurb: "Qwen3 235B-A22B (2507), a multilingual instruction-tuned MoE with 22B active parameters." },
  "deepseek-v4-flash": { vramQ4GB: null, note: "284B MoE (13B active), 1M ctx", slug: "deepseek/deepseek-v4-flash", blurb: "DeepSeek V4 Flash, an efficiency-tuned MoE (284B total / 13B active, 1M context) - near the top here for a fraction of a cent per task." },
  "deepseek-v4-pro":   { vramQ4GB: null, note: "1.6T MoE (49B active), 1M ctx", slug: "deepseek/deepseek-v4-pro", blurb: "DeepSeek V4 Pro, a giant MoE (1.6T total / 49B active, 1M context) - the frontier-open generalist that tops this leaderboard." },
  "deepseek-v3.2":     { vramQ4GB: null, slug: "deepseek/deepseek-v3.2", blurb: "DeepSeek V3.2, a large MoE balancing compute efficiency with strong reasoning and agentic tool-use." },
  "deepseek-r1":       { vramQ4GB: null, note: "671B, open reasoning", slug: "deepseek/deepseek-r1", blurb: "DeepSeek R1, a 671B open reasoning model with fully open chain-of-thought - strong at math/logic but underperforms at agentic coding here." },
  "qwen3-coder-480b":  { vramQ4GB: null, note: "480B MoE (35B active)", slug: "qwen/qwen3-coder", blurb: "Qwen3-Coder 480B-A35B, Alibaba's flagship open MoE coding model for agentic tasks." },
  "qwen3-coder-plus":  { vramQ4GB: null, slug: "qwen/qwen3-coder-plus", blurb: "Qwen3-Coder Plus, Alibaba's proprietary build of Qwen3-Coder 480B, tuned as an autonomous coding agent." },
  "qwen3-max":         { vramQ4GB: null, slug: "qwen/qwen3-max", blurb: "Alibaba Qwen3-Max, the large flagship generalist (reasoning, instruction-following, long-tail knowledge)." },
  "kimi-k2.7-code":    { vramQ4GB: null, slug: "moonshotai/kimi-k2.7-code", blurb: "Moonshot Kimi K2.7 Code, a coding-focused model in the K2 family built for end-to-end programming over long contexts." },
  "kimi-k2-thinking":  { vramQ4GB: null, slug: "moonshotai/kimi-k2-thinking", blurb: "Moonshot Kimi K2 Thinking, the trillion-param-class open reasoning variant for agentic, long-horizon tasks." },
  "glm-4.6":           { vramQ4GB: null, note: "200K ctx", slug: "z-ai/glm-4.6", blurb: "Z.ai GLM-4.6, a generalist with a 200K context window (up from 128K in 4.5)." },
  "glm-4.7":           { vramQ4GB: null, slug: "z-ai/glm-4.7", blurb: "Z.ai GLM-4.7, a flagship generalist with stronger programming and more stable multi-step reasoning." },
  "glm-5.1":           { vramQ4GB: null, slug: "z-ai/glm-5.1", blurb: "Z.ai GLM-5.1, the latest flagship - a major leap in coding and long-horizon tasks; top-cluster here." },
  "minimax-m2.7":      { vramQ4GB: null, slug: "minimax/minimax-m2.7", blurb: "MiniMax M2.7, an agentic generalist built for long-horizon, real-world productivity tasks." },
  "minimax-m3":        { vramQ4GB: null, note: "multimodal, 1M ctx", slug: "minimax/minimax-m3", blurb: "MiniMax M3, a multimodal foundation model (text/image/video in, 1M context); used here as a coding agent." },

  // closed frontier baselines (not open weights - shown for comparison)
  "gpt-5.5":           { vramQ4GB: null, note: "closed frontier", slug: "openai/gpt-5.5", blurb: "OpenAI GPT-5.5, a frontier closed flagship - here as a baseline, and the model behind codex in the orchestration build." },
  "claude-opus-4.8":   { vramQ4GB: null, note: "closed frontier", slug: "anthropic/claude-opus-4.8", blurb: "Anthropic Claude Opus 4.8, a frontier closed flagship - here as a baseline, and the conductor model that drove the orchestration." },
};

// Model-card URL for an arm label (OpenRouter page), or null if unknown / a mix.
export function modelCardUrl(label: string): string | null {
  const m = MODEL_META[label];
  return m?.slug ? `https://openrouter.ai/${m.slug}` : null;
}

// Short VRAM-to-run label: "~9 GB" (fits a consumer GPU at q4), "cloud" (too big
// for any consumer card), or "" for a mix / unknown arm. Approximate q4 estimate.
export function vramLabel(label: string): string {
  const m = MODEL_META[label];
  if (!m) return "";
  return m.vramQ4GB == null ? "cloud" : `~${m.vramQ4GB} GB`;
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
