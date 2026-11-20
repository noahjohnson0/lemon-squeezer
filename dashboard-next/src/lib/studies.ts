import type { Status } from "@/components/ui";

export type StudyInfo = { href: string; title: string; blurb: string; venue: string; status: Status[]; when: string };

export const STUDIES: StudyInfo[] = [
  {
    href: "/studies/tool-calling-week/",
    title: "Big local models as tool-calling agents",
    blurb: "A preregistered week-long screen of open-weight models that fit in 128 GB, scored on the end state of files, mail and messages.",
    venue: "128 GB workstation · llama.cpp",
    status: ["explore", "pending"],
    when: "November 2026",
  },
  {
    href: "/studies/harness-bakeoff/",
    title: "Coding-agent harness bake-off",
    blurb: "Same model, same tasks, different agent harness. On weak models the harness moves the score by 60 points.",
    venue: "Cloud-served open weights",
    status: ["solid"],
    when: "June 2026",
  },
  {
    href: "/studies/cloud-models/",
    title: "Open models as coding agents, compared",
    blurb: "Single models and multi-model mixes on one coding suite, with intervals and cost per task. The top is a tie.",
    venue: "Cloud-served open weights",
    status: ["wide"],
    when: "June 2026",
  },
  {
    href: "/studies/local-4070/",
    title: "Coding agents on a 12 GB consumer GPU",
    blurb: "Quantized models on an RTX 4070 Super: scores by harness, power draw, and a matched local-vs-cloud check.",
    venue: "12 GB GPU · Ollama",
    status: ["explore"],
    when: "May to June 2026",
  },
];
