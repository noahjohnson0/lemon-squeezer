// Small view helpers over studio/summary.json, shared by the home page and the study page.
import { studio, type StudioRow, type StudioComparison } from "./site-data";
import type { Status } from "@/components/ui";

export const row = (suite: string, key: string): StudioRow | undefined =>
  studio().exploration[suite]?.find((r) => r.key === key);

export const cmp = (prefix: string): StudioComparison => {
  const c = studio().comparisons.find((x) => x.name.startsWith(prefix));
  if (!c) throw new Error(`studio comparison not found: ${prefix}`);
  return c;
};

export const verdictStatus = (v: string): Status =>
  v === "A ahead" || v === "B ahead" ? "solid" : v === "same tasks solved" ? "wide" : "wide";

export const verdictText = (v: string) =>
  v === "same tasks solved" ? "Same tasks solved" : v === "A ahead" ? "CI clears zero" : "Too wide to call";

export const fracPct = (r: StudioRow) => (100 * r.solved) / r.tasks;

export function finalState() {
  const f = studio().final;
  const done = f.models.filter((m) => m.status === "done");
  return { ...f, done, partial: f.models.filter((m) => m.status !== "done") };
}

export const shortName = (m: string) => m.replace(/ \(.*\)$/, "");
