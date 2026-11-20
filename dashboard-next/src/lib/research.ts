// The research track. One entry per line of work. A line states its question and where it
// stands against the bar. It states no result until all three bar items are "done"; at that
// point it gets a paper page and `paper` points to it.

export type BarState = "done" | "part" | "no";
export type BarItem = { s: BarState; d: string };

export type ResearchLine = {
  slug: string;
  title: string;
  question: string;
  setup: string; // hardware and models, described generically
  state: string; // one or two words
  related: BarItem; // related-work check
  effect: BarItem; // an effect with an interval
  replicated: BarItem; // seen again on a second seed set, model or machine
  paper?: string; // href of the paper page, once the bar is cleared
};

export const BAR_TEXT: Record<BarState, string> = { done: "Done", part: "Partial", no: "Not yet" };

export const LINES: ResearchLine[] = [
  {
    slug: "neural-engine",
    title: "Higher-precision weights on the Neural Engine beside a 4-bit GPU model",
    question:
      "A quantized model runs on the GPU. This line asks whether the Apple Neural Engine can run some of its dense parts from the original weights at the same time, so that prefill is faster and the output is closer to a higher-precision build.",
    setup: "Laptop-class Apple silicon, a hybrid mixture-of-experts model, MLX and Core ML",
    state: "In progress",
    related: { s: "done", d: "The prior systems were reviewed, and they use the extra engine at equal or lower precision." },
    effect: { s: "part", d: "It has been measured on a few texts for one model, with no interval yet." },
    replicated: { s: "no", d: "It has run on one machine and one model so far." },
  },
  {
    slug: "expert-pruning",
    title: "Domain pruning of routed experts",
    question:
      "This line asks how many of a mixture-of-experts model's routed experts one domain of agent work needs, and whether the rest can be removed from memory with no loss in task success.",
    setup: "A 35B mixture-of-experts model at 4 bits, multi-host system administration tasks",
    state: "In progress",
    related: { s: "no", d: "The review so far covers the benchmark, and the pruning papers have not been checked." },
    effect: { s: "part", d: "Paired pass rates have intervals on held-out tasks, and the harder tier is still too wide." },
    replicated: { s: "part", d: "It has three seeds on one tier and one model." },
  },
  {
    slug: "adding-experts",
    title: "Training new experts in a pretrained model's cold slots",
    question:
      "The experts a domain rarely routes to are spare capacity. This line asks whether training new domain experts in those slots gives the gain of fine-tuning the hot experts, with less damage to general text.",
    setup: "A 1B mixture-of-experts model, one 12 GB GPU",
    state: "In progress",
    related: { s: "no", d: "The search has not been started." },
    effect: { s: "part", d: "The study is preregistered. The first seeds have run and the rest are queued." },
    replicated: { s: "no", d: "It has run on one model." },
  },
  {
    slug: "phase-routing",
    title: "Kuramoto routing: oscillator phases as a mixture-of-experts router",
    question:
      "A linear router scores every token on its own at every layer. This line asks whether a router built on coupled oscillator phases, which carries state across positions and depth, routes more coherently, and what that costs in modelling quality.",
    setup: "A small byte-level language model trained from scratch, and a retrofit into a pretrained 1B model",
    state: "Paper drafted",
    related: { s: "part", d: "The nearest prior work uses phases for attention, and a full search for routing work is still to do." },
    effect: { s: "done", d: "Each arm has three seeds, and the ablations are done." },
    replicated: { s: "part", d: "A longer schedule and a retrofit have run, and a second scale from scratch has not." },
  },
  {
    slug: "agent-contracts",
    title: "Pre- and postconditions checked on the real host for a system-administration agent",
    question:
      "An agent states what must be true before and after each command, and the environment checks those claims on the host. This line asks whether that raises the rate of finished tasks or lowers the rate of false claims of completion.",
    setup: "A multi-host SSH benchmark with programmatic end-state checks, 4B and 35B models",
    state: "Parked",
    related: { s: "done", d: "The benchmark and agent-training literature was reviewed." },
    effect: { s: "no", d: "The paired runs are done, and the interval on the difference includes zero and is wide." },
    replicated: { s: "part", d: "It has run on two model sizes." },
  },
  {
    slug: "multi-machine",
    title: "Long tasks on larger quantizations across several machines",
    question:
      "This line asks whether an agent finishes more long tasks when the same model is split across several machines at a larger quantization and a longer context, compared with one machine at a smaller quantization.",
    setup: "Two or three Apple silicon machines linked by Thunderbolt",
    state: "Not started",
    related: { s: "no", d: "The search has not been started." },
    effect: { s: "no", d: "There are no runs yet." },
    replicated: { s: "no", d: "There are no runs yet." },
  },
];

export const cleared = (l: ResearchLine) => l.related.s === "done" && l.effect.s === "done" && l.replicated.s === "done";
