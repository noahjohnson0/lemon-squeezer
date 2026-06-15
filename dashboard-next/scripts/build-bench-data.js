#!/usr/bin/env node
/**
 * build-bench-data.js - aggregate bench/results into a committed bench-data.json
 * at the repo root, then mirror it into dashboard-next/public/ for the static
 * export. This mirrors the runs.jsonl pattern:
 *   - Locally we have bench/results/*; run this to refresh the aggregate.
 *   - bench-data.json at repo root IS committed (since bench/results is gitignored).
 *   - dashboard-next/public/bench-data.json is a symlink (dev) or copy (CI),
 *     like runs.jsonl.
 *
 * Reads:
 *   ../bench/results/<sweep>/summary.json       (one per sweep, if present)
 *   ../bench/results/<sweep>/per_question.jsonl (one Q per line)
 *   ../bench/<qset>.jsonl                        (qset metadata: domain, aliases, expected_corpora)
 *
 * Skips ../bench/results/_quarantined-buggy-manifest/ (invalid runs).
 * Skips sweep dirs missing summary.json (in-progress sweeps).
 *
 * Writes:
 *   <repo-root>/bench-data.json
 *
 * If bench/results/ is missing entirely (e.g. CI fresh checkout), the existing
 * <repo-root>/bench-data.json is left untouched.
 *
 * Schema:
 *   {
 *     generated_at: ISO timestamp,
 *     sweeps: [ {sweep_id, summary fields..., per_q: [{...truncated...}]} ],
 *     qsets:  { "<qset>": { questions: [{id, question, answer_value, domain?, normalized_aliases?, aliases?, expected_corpora?}] } }
 *   }
 *
 * Model answers are truncated to MODEL_ANSWER_MAX chars to keep the bundle small.
 */
"use strict";
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..", "..");        // repo root
const BENCH = path.join(ROOT, "bench");
const RES = path.join(BENCH, "results");
const OUT = path.join(ROOT, "bench-data.json");

const MODEL_ANSWER_MAX = 1200; // chars; bigger answers get truncated with an ellipsis marker

function readJSON(p) {
  return JSON.parse(fs.readFileSync(p, "utf8"));
}

function readJSONL(p) {
  const text = fs.readFileSync(p, "utf8");
  const out = [];
  for (const line of text.split("\n")) {
    const t = line.trim();
    if (!t) continue;
    try {
      out.push(JSON.parse(t));
    } catch {
      // skip malformed
    }
  }
  return out;
}

function truncate(s, max) {
  if (typeof s !== "string") return s;
  if (s.length <= max) return s;
  return s.slice(0, max) + "…";
}

function main() {
  if (!fs.existsSync(RES)) {
    if (fs.existsSync(OUT)) {
      console.warn(`[bench] no ${RES}; leaving existing ${OUT} untouched`);
    } else {
      console.warn(`[bench] no ${RES} and no existing ${OUT}; writing empty stub`);
      fs.writeFileSync(OUT, JSON.stringify({ generated_at: new Date().toISOString(), sweeps: [], qsets: {} }, null, 0));
    }
    return;
  }

  const dirs = fs.readdirSync(RES, { withFileTypes: true })
    .filter((e) => e.isDirectory())
    .map((e) => e.name)
    .filter((n) => !n.startsWith("_"))         // skip _quarantined-*
    .sort();

  const sweeps = [];
  const qsetsNeeded = new Set();

  for (const name of dirs) {
    const dir = path.join(RES, name);
    const sj = path.join(dir, "summary.json");
    const pj = path.join(dir, "per_question.jsonl");
    if (!fs.existsSync(sj)) {
      console.warn(`[bench] skipping ${name}: no summary.json (in-progress?)`);
      continue;
    }
    let summary;
    try {
      summary = readJSON(sj);
    } catch (e) {
      console.warn(`[bench] skipping ${name}: bad summary.json (${e.message})`);
      continue;
    }
    qsetsNeeded.add(summary.qset);

    let perQ = [];
    if (fs.existsSync(pj)) {
      try {
        perQ = readJSONL(pj).map((r) => ({
          i: r.i,
          id: r.id,
          question: r.question,
          answer_value: r.answer_value,
          model_answer: truncate(r.model_answer ?? "", MODEL_ANSWER_MAX),
          hit: !!r.hit,
          matched_alias: r.matched_alias ?? null,
          wall_seconds: r.wall_seconds,
          tokens_in: r.tokens_in,
          tokens_out: r.tokens_out,
          tool_calls: r.tool_calls,
          exit_code: r.exit_code,
        }));
      } catch (e) {
        console.warn(`[bench] ${name}: bad per_question.jsonl (${e.message})`);
      }
    }

    sweeps.push({
      sweep_id: name,
      ts: summary.ts,
      qset: summary.qset,
      model: summary.model,
      harness: summary.harness,
      tag: summary.tag ?? null,
      corpora: summary.corpora ?? (summary.corpus ? summary.corpus.split(",") : []),
      n: summary.n ?? perQ.length,
      hits: summary.hits ?? perQ.filter((r) => r.hit).length,
      accuracy: summary.accuracy,
      score_pct: summary.score_pct,
      wall_seconds_total: summary.wall_seconds_total,
      wall_seconds_mean: summary.wall_seconds_mean,
      tokens_in_total: summary.tokens_in_total,
      tokens_out_total: summary.tokens_out_total,
      tool_calls_total: summary.tool_calls_total,
      host: summary.host,
      base_url: summary.base_url,
      per_q: perQ,
    });
  }

  // Load referenced qset metadata
  const qsets = {};
  for (const qset of qsetsNeeded) {
    const p = path.join(BENCH, `${qset}.jsonl`);
    if (!fs.existsSync(p)) {
      console.warn(`[bench] qset file missing: ${p}`);
      qsets[qset] = { questions: [] };
      continue;
    }
    const questions = readJSONL(p).map((q) => ({
      id: q.id,
      question: q.question,
      answer_value: q.answer_value,
      domain: q.domain ?? null,
      normalized_aliases: q.normalized_aliases ?? null,
      aliases: q.aliases ?? null,
      expected_corpora: q.expected_corpora ?? null,
    }));
    qsets[qset] = { questions };
  }

  // Newest sweep first
  sweeps.sort((a, b) => b.ts.localeCompare(a.ts));

  const payload = {
    generated_at: new Date().toISOString(),
    sweeps,
    qsets,
  };
  fs.writeFileSync(OUT, JSON.stringify(payload));
  const bytes = fs.statSync(OUT).size;
  console.log(`[bench] wrote ${OUT} - ${sweeps.length} sweeps, ${Object.keys(qsets).length} qsets, ${(bytes / 1024).toFixed(1)} KB`);
}

main();
