#!/usr/bin/env node
// scrub-out.mjs - last build step: strip home-directory paths from data files that public/
// carries into out/ (e.g. scores.json, written by bin/build-scores), then fail the build if
// any machine-specific string is left anywhere in the static export.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const OUT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "out");
const HOME_RE = /(\/Users|\/home)\/[^/\\"]+/g;
const BAD = /\/Users\/|mac-studio|\bsvr\b|192\.168\.\d+\.\d+/;
const TEXT = /\.(json|jsonl|md|csv|txt|html|js)$/;

function* walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) yield* walk(p);
    else if (TEXT.test(e.name)) yield p;
  }
}

let scrubbed = 0;
const bad = [];
for (const p of walk(OUT)) {
  let t = fs.readFileSync(p, "utf8");
  if (/\.(json|jsonl|md|csv|txt)$/.test(p) && HOME_RE.test(t)) {
    t = t.replace(HOME_RE, "~");
    fs.writeFileSync(p, t);
    scrubbed++;
  }
  const m = t.match(BAD);
  if (m) bad.push(`${path.relative(OUT, p)}: "${m[0]}"`);
}
if (bad.length) {
  console.error(`[scrub-out] machine-specific strings left in the export:\n  ${bad.join("\n  ")}`);
  process.exit(1);
}
console.log(`[scrub-out] ok (${scrubbed} file(s) scrubbed)`);
