import type { Metadata } from "next";
import Link from "next/link";
import { Chip, Note } from "@/components/ui";
import { BOOT_B } from "@/lib/stats";
import { BUGS } from "@/lib/bugs";

export const metadata: Metadata = {
  title: "Methods",
  description: "How benchmark runs are scored, how intervals are computed, how studies are preregistered, and the harness bug log.",
};

export default function Methods() {
  return (
    <>
      <header className="study-head col-wide">
        <div className="col" style={{ marginLeft: 0 }}>
          <div className="kicker">Benchmarks track · Methods</div>
          <h1>How the numbers are made</h1>
          <p className="dek">
            Every benchmark result on this site comes from running an agent, scoring the outcome with a script and aggregating with an
            interval. This page describes each step and the problems that were found in it.
          </p>
        </div>
        <nav className="toc" aria-label="On this page">
          <a href="#harness">Harnesses</a>
          <a href="#scoring">Scoring</a>
          <a href="#stats">Statistics</a>
          <a href="#labels">Labels</a>
          <a href="#prereg">Preregistration</a>
          <a href="#explore">Exploration and final pass</a>
          <a href="#bugs">Harness bug log</a>
          <a href="#audit">Rubric audit</a>
          <a href="#gaps">Known gaps</a>
        </nav>
      </header>

      <div className="col prose">
        <h2 id="harness">Harnesses</h2>
        <p>
          An agent harness is the program around a model that turns its replies into actions: it offers tools, executes the calls, returns the
          results and decides when to stop. It is treated as an experimental variable alongside the model, since on weaker models it moves the
          score by as much as the model does.
        </p>
        <ul>
          <li>
            <strong>Coding suite.</strong>{" "}Our reference harness is <em>squeezer</em>, a ~250-line, dependency-free tool-calling loop with four
            tools (read a file, write a file, list files, run a shell command) that talks to any OpenAI-compatible endpoint. It was kept small
            so that it is easy to read and change. Third-party harnesses (aider, pi, Cline, opencode, Crush, Codex CLI, Claude Code) run through small shims
            with the same prompts. Multi-model <em>mixes</em>{" "}wire several models over one workspace: plan-then-implement, draft-critique-refine,
            ensemble-and-judge, and write-tests-then-fix.
          </li>
          <li>
            <strong>Tool-calling suite.</strong>{" "}A separate, jailed harness gives the model file, search, mail, messaging and browser tools over a
            small simulated world, with an optional Python sandbox. It caps each task at 150 steps and each reply at 16k tokens.
          </li>
        </ul>
        <div className="pipeline" aria-label="Run pipeline">
          <span className="box">task prompt</span>
          <span className="arr">→</span>
          <span className="box">harness + model</span>
          <span className="arr">→</span>
          <span className="box">workspace / world state</span>
          <span className="arr">→</span>
          <span className="box">rubric or checker</span>
          <span className="arr">→</span>
          <span className="box">one row of data</span>
        </div>

        <h2 id="scoring">Scoring</h2>
        <p>Every score comes from running the code or checking the end state. No score comes from a language model or from the transcript.</p>
        <ul>
          <li>
            <strong>Coding tasks</strong>{" "}ship a rubric script that imports or runs the program the agent wrote and checks its behaviour on
            inputs. The checks are weighted toward runtime correctness, so a program that looks right and returns wrong answers loses most of
            its points. The score is the percentage of checks passed. Every check always emits, so the denominator is constant.
          </li>
          <li>
            <strong>Tool-calling tasks</strong>{" "}are checked on the end state, which is the files on disk, mailbox labels, drafts sent and rows
            in the message database. A task counts as solved only when every check passes. Each hard task has a reference solution that passes and a
            test that an untouched workspace fails.
          </li>
          <li>
            Environment-dependent tasks that give every model the same score (one needs live network sockets) are excluded from aggregates and
            listed where they are excluded.
          </li>
        </ul>

        <h2 id="stats">Statistics</h2>
        <ul>
          <li>
            <strong>Aggregate per task first.</strong>{" "}Trials of the same task share its difficulty, so they are not independent. A model&apos;s
            score is the mean over tasks of each task&apos;s mean over its trials, so every task weighs the same. A failed run counts as zero.
          </li>
          <li>
            <strong>Cluster bootstrap.</strong>{" "}The 95% interval on that score resamples tasks with replacement ({BOOT_B.toLocaleString("en-US")}{" "}
            resamples, fixed seed) and takes the 2.5th and 97.5th percentiles. Models with fewer than 8 tasks get no interval and are not ranked.
          </li>
          <li>
            <strong>Wilson intervals</strong>{" "}for solve rates (k of n tasks solved), which behave at 0% and 100% where the normal approximation
            does not.
          </li>
          <li>
            <strong>Paired differences.</strong>{" "}When two conditions ran on the same tasks (two harnesses, two models, with and without a tool),
            we difference them per task and bootstrap the mean difference. Unpaired cells are dropped. Conclusions are drawn from paired
            comparisons only.
          </li>
          <li>
            <strong>Rule.</strong>{" "}If the 95% interval on a difference includes zero, the result is reported as too wide to call, whatever the
            point estimate is.
          </li>
        </ul>

        <h2 id="labels">What the labels mean</h2>
        <ul style={{ listStyle: "none", paddingLeft: 0 }}>
          <li>
            <Chip s="solid" /> The 95% interval on the claimed difference excludes zero. The direction is supported, and the size may still be
            uncertain.
          </li>
          <li>
            <Chip s="wide" /> The interval includes zero. We do not claim a difference either way.
          </li>
          <li>
            <Chip s="explore" /> Run while the method was still changing, or with too few trials to rank. Use it to pick candidates for a final pass.
          </li>
          <li>
            <Chip s="pending" /> A frozen, preregistered pass is running and will replace the exploration numbers.
          </li>
          <li>
            <Chip s="hist" /> An earlier write-up kept for the record. It is superseded by numbers computed from current data.
          </li>
        </ul>

        <h2 id="prereg">Preregistration and amendments</h2>
        <p>
          A study starts with a written question, model list, method, analysis and a stated expectation, fixed before the first episode. After
          that, every change is added as a dated amendment that records what had been observed when the change was made. Examples are a
          toolset dropped after one pass showed that it fails for a known reason, and a bug fix with the rows it touched. Rows run before a
          change are kept as they were and labelled. Expectations that turn out wrong are reported as wrong.
        </p>

        <h2 id="explore">Exploration and the final pass</h2>
        <p>
          Exploration is where the harness gets debugged. It has one trial per task and fixes between runs, and models are dropped and
          added. Its numbers are a screen. The <em>final pass</em>{" "}then runs the shortlisted models on a frozen harness (hashed before the start), on fresh workspaces at
          a seed never used in exploration, with the analysis fixed in advance. Only final-pass numbers are presented as a ranking. A model&apos;s
          final score counts once its whole pass is done, and partial passes show progress only.
        </p>

        <h2 id="bugs">Harness bug log</h2>
        <p>
          The tool-calling screen found {BUGS.length} harness bugs in its first days. Each was fixed with a test before the final pass. They
          are published here since the same bugs can occur in any agent benchmark.
        </p>
        <ol className="buglog">
          {BUGS.map((b) => (
            <li key={b.t}>
              <span className="bt">{b.t}</span> {b.d}
              <span className="eff">Effect: {b.e}</span>
            </li>
          ))}
        </ol>
        <Note title="Checks now applied to every benchmark">
          <ul>
            <li>Score the end state.</li>
            <li>Read every failure before believing it.</li>
            <li>Check what a grammar-constrained decoder can and cannot emit.</li>
            <li>Jail code execution away from the answers, and test that it is jailed.</li>
            <li>Pin the clock of any simulated world.</li>
            <li>Give every checker a reference solution that passes and an untouched workspace that fails.</li>
          </ul>
        </Note>

        <h2 id="audit">The coding-suite rubric audit</h2>
        <p>
          An adversarial review of the coding suite in June 2026 found 26 rubrics that could award 100% to a stub that does not work. An
          import error dropped the behavioural checks and collapsed the denominator, so a file containing only <code>x = 1</code>{" "}could
          pass. All 26 were rewritten so that every check always emits, and the 2,894 affected runs were re-scored. The same review found an
          unpaired harness comparison (a resume key that ignored the experiment tag), answer leakage in one task&apos;s comments, and
          best-of-trials aggregation. Each was fixed, and every number on this site is from after the audit. The counts in this paragraph
          come from the audit record in the repository&apos;s <code>ROADMAP.md</code>. They are the only result numbers on the site that are
          not computed from the data files at build time.
        </p>

        <h2 id="gaps">Known gaps</h2>
        <ul>
          <li>The coding-suite agent shell is not sandboxed, so a model could read a rubric mid-run. This has not been observed.</li>
          <li>Coding-suite sampling used provider defaults. Pinned temperature and seed are wired and have not been used for a full sweep.</li>
          <li>All tasks are ours. A standard external benchmark (Aider polyglot or SWE-bench-lite) is queued.</li>
          <li>The tool-calling harness is not public yet. Its per-task rows are public.</li>
        </ul>
        <p>
          See the <Link href="/data/">data</Link>{" "}page for the files every number is computed from.
        </p>
      </div>
    </>
  );
}
