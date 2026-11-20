import type { Status } from "@/components/ui";

export type StudyInfo = { href: string; title: string; blurb: string; venue: string; status: Status[]; when: string };

export const STUDIES: StudyInfo[] = [
  {
    href: "/studies/tool-calling-week/",
    title: "Big local models as tool-calling agents",
    blurb: "A preregistered screen of open-weight models that fit in 128 GB, scored on the end state of files, mail and messages. The final pass is running.",
    venue: "128 GB workstation · llama.cpp",
    status: ["explore", "pending"],
    when: "November 2026",
  },
  {
    href: "/studies/harness-bakeoff/",
    title: "Coding-agent harness bake-off",
    blurb: "The same model and tasks under different agent harnesses. Weak models gained the most from an edit-format harness, and strong models tied.",
    venue: "Cloud-served open weights",
    status: ["solid"],
    when: "June 2026",
  },
  {
    href: "/studies/cloud-models/",
    title: "Open models as coding agents, compared",
    blurb: "Single models and multi-model mixes on one coding suite, with intervals and cost per task. The top group is tied.",
    venue: "Cloud-served open weights",
    status: ["wide"],
    when: "June 2026",
  },
  {
    href: "/studies/local-4070/",
    title: "Coding agents on a 12 GB consumer GPU",
    blurb: "Quantized models on an RTX 4070 Super: scores by harness, power draw, and a paired check of local against rented.",
    venue: "12 GB GPU · Ollama",
    status: ["explore"],
    when: "May to June 2026",
  },
];
