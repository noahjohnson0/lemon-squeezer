#!/usr/bin/env node
// stage-data.mjs - write the public data downloads into public/data/ for the static export.
//
// The site's pages compute their numbers at build time straight from the repo-root files
// (runs.jsonl, studio/summary.json, studio/rows/). This script publishes the same files as
// downloads, with machine-specific strings removed (home-directory paths in old local runs'
// extra_flags, the scoring host/base_url in the retrieval sweeps). No values are changed.
//
// It also replaces public/runs.jsonl and public/bench-data.json (copied in by the deploy
// workflow, or symlinked locally) with the same sanitized copies, so the raw files are not
// what gets published.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const SITE = path.resolve(HERE, "..");
const ROOT = path.resolve(SITE, "..");
const PUB = path.join(SITE, "public");
const OUT = path.join(PUB, "data");

const HOME_RE = /(\/Users|\/home|C:\\\\Users|C:\/Users)\/[^/\\"]+/g;
const scrub = (s) => s.replace(HOME_RE, "~");

function writeFresh(p, text) {
  // unlink first: a dev symlink must not be written through to the repo-root file
  try { fs.lstatSync(p); fs.unlinkSync(p); } catch {}
  fs.writeFileSync(p, text);
}

fs.mkdirSync(OUT, { recursive: true });
const written = [];

// runs.jsonl (coding suite: local GPU + cloud)
const runsSrc = path.join(ROOT, "runs.jsonl");
if (fs.existsSync(runsSrc)) {
  const text = scrub(fs.readFileSync(runsSrc, "utf8"));
  writeFresh(path.join(OUT, "runs.jsonl"), text);
  writeFresh(path.join(PUB, "runs.jsonl"), text);
  written.push("runs.jsonl");
}

// studio summary + rows (tool-calling week screen)
const sumSrc = path.join(ROOT, "studio", "summary.json");
if (fs.existsSync(sumSrc)) {
  writeFresh(path.join(OUT, "studio-summary.json"), scrub(fs.readFileSync(sumSrc, "utf8")));
  written.push("studio-summary.json");
}
const rowsDir = path.join(ROOT, "studio", "rows");
if (fs.existsSync(rowsDir)) {
  const lines = [];
  for (const f of fs.readdirSync(rowsDir).filter((f) => f.endsWith(".jsonl")).sort()) {
    const tag = f.replace(/\.jsonl$/, "");
    for (const l of fs.readFileSync(path.join(rowsDir, f), "utf8").split("\n")) {
      if (!l.trim()) continue;
      try {
        lines.push(JSON.stringify({ tag, ...JSON.parse(l) }));
      } catch {}
    }
  }
  writeFresh(path.join(OUT, "studio-rows.jsonl"), scrub(lines.join("\n") + "\n"));
  written.push("studio-rows.jsonl");
}
const tagsSrc = path.join(ROOT, "studio", "tags.json");
if (fs.existsSync(tagsSrc)) {
  writeFresh(path.join(OUT, "studio-tags.json"), fs.readFileSync(tagsSrc, "utf8"));
  written.push("studio-tags.json");
}

// bench-data.json (retrieval sweeps): drop host and base_url
const benchSrc = path.join(ROOT, "bench-data.json");
if (fs.existsSync(benchSrc)) {
  const d = JSON.parse(fs.readFileSync(benchSrc, "utf8"));
  for (const s of d.sweeps ?? []) { delete s.host; delete s.base_url; }
  const text = scrub(JSON.stringify(d));
  writeFresh(path.join(OUT, "bench-data.json"), text);
  writeFresh(path.join(PUB, "bench-data.json"), text);
  written.push("bench-data.json");
}

// guard: fail the build if anything machine-specific is left in what we publish
const BAD = /\/Users\/|mac-studio|\bsvr\b|192\.168\.|10\.0\.\d+\.\d+/;
for (const f of fs.readdirSync(OUT)) {
  const t = fs.readFileSync(path.join(OUT, f), "utf8");
  const m = t.match(BAD);
  if (m) {
    console.error(`[stage-data] ${f} still contains "${m[0]}"; refusing to publish`);
    process.exit(1);
  }
}
console.log(`[stage-data] wrote public/data/: ${written.join(", ")}`);
