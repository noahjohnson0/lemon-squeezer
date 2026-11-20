import type { Metadata } from "next";
import Link from "next/link";
import { Chip, Note } from "@/components/ui";
import { BOOT_B } from "@/lib/stats";

export const metadata: Metadata = {
  title: "Methods",
  description: "How runs are scored, how intervals are computed, how studies are preregistered, and the harness bugs we found along the way.",
};

const BUGS: { t: string; d: string; e: string }[] = [
  {
    t: "The decoding grammar forced tool-call keys into schema order.",
    d: "llama.cpp's tool-call grammar accepts object keys only in the order the schema lists them. A bulk-move tool listed its optional glob after the destination, so once a model had written the destination it could never add a glob, and it looped. Fixed by moving the key up and making it required.",
    e: "Made models look worse",
  },
  {
    t: "The mail mock ignored parentheses.",
    d: "Queries with ( ) groups or from:(a OR b) silently returned nothing, and a model concluded the mailbox was empty. Replaced with a real query parser. Brace globs (*.{a,b}) also matched nothing.",
    e: "Made models look worse",
  },
  {
    t: "A reply cut off mid tool call was executed.",
    d: "When a reply hit the token cap inside a tool call, the broken call ran and the next request failed with a server error, killing the trial. It now ends the trial as out_of_tokens.",
    e: "Made models look worse",
  },
  {
    t: "An unexpected tool exception crashed the worker, and the task silently reran.",
    d: "Editing a binary database or passing a non-string count raised an exception type the sandbox did not catch. The task then restarted from scratch in a new directory: a hidden second attempt that turned two failures into passes. Every tool exception now goes back to the model as a tool error.",
    e: "Made models look better",
  },
  {
    t: "Checkers crashed on bytecode caches.",
    d: "Models that imported their own code to test it left __pycache__ behind, and the checker crashed on it: good behaviour scored as a fail. Checkers skip bytecode and the Python sandbox no longer writes it.",
    e: "Made models look worse",
  },
  {
    t: "The system prompt called the agent a file manager.",
    d: "One model declined a refund-triage task because 'the tools available to me are limited to managing files'. The prompt now names the apps, and says nobody will answer questions: assume, say what you assumed, finish.",
    e: "Made models look worse",
  },
  {
    t: "Reasoning was off by default for one model.",
    d: "Its chat template defaults reasoning to none and the configuration never set it: 1 of 993 turns reasoned. That row is reported as 'reasoning off', not as the model.",
    e: "Made one model look worse",
  },
  {
    t: "The largest model did not fit at the shared context length.",
    d: "At 131k context the 235B model ran out of memory; it ran at 65k with an 8-bit KV cache, so its rows are not on the same context as the others.",
    e: "Comparability",
  },
  {
    t: "The code sandbox could read the harness.",
    d: "run_python ran inside the worker container, which had the checkers, expected answers and reference solutions mounted read-only. A scan of every run_python call found no model touching a path outside its workspace. It now runs in a fresh container per call with only the workspace mounted, no network and a read-only root, with a test that the harness paths do not exist inside it.",
    e: "Could have made models look better",
  },
  {
    t: "The simulated world's date disagreed with the host clock.",
    d: "The mailbox and intranet are fixed at one date; the host clock was three weeks later. A model asked Python for today's date, computed '30 days ago' from the real date and archived the wrong newsletters. The prompt now states the world's date and the sandbox runs under a fake clock. The final pass restarted.",
    e: "Made models look worse",
  },
  {
    t: "Three checker bugs in the hardest suite.",
    d: "Two code checkers copied only part of the workspace, so a regression test that read a data file failed on a correct fix; one prompt named a policy file that was never created; and a numbered '1. REFUSED:' line was not read as a refusal.",
    e: "Made models look worse",
  },
  {
    t: "Killed rows were counted as done.",
    d: "Rows interrupted when the model server was stopped mid-task were recorded as finished. They are now retried.",
    e: "Made models look worse",
  },
];

export default function Methods() {
  return (
    <>
      <header className="study-head col-wide">
        <div className="col" style={{ marginLeft: 0 }}>
          <div className="kicker">Methods</div>
          <h1>How the numbers are made</h1>
          <p className="dek">
            Every result on this site comes from running an agent, scoring the outcome mechanically, and aggregating with an interval. This page
            says how each step works and what has gone wrong with it.
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
          results and decides when to stop. We treat it as an experimental variable alongside the model, because it moves scores as much as
          the model does on weaker models.
        </p>
        <ul>
          <li>
            <strong>Coding suite.</strong>{" "}Our reference harness is <em>squeezer</em>, a ~250-line, dependency-free tool-calling loop with four
            tools (read a file, write a file, list files, run a shell command) that talks to any OpenAI-compatible endpoint. It is minimal and
            transparent on purpose. Third-party harnesses (aider, pi, Cline, opencode, Crush, Codex CLI, Claude Code) run through small shims
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

        <h2 id="scoring">Scoring: run the code, check the end state</h2>
        <p>Nothing on this site is scored by a language model or by reading the transcript.</p>
        <ul>
          <li>
            <strong>Coding tasks</strong>{" "}ship a rubric script that imports or runs the program the agent wrote and checks its behaviour on
            inputs, weighted toward runtime correctness: a program that looks right but returns wrong answers loses most of its points. The
            score is the percentage of checks passed. Every check always emits, so the denominator is constant.
          </li>
          <li>
            <strong>Tool-calling tasks</strong>{" "}are checked on the end state: the files on disk, mailbox labels, drafts sent, rows in the
            message database. A task counts as solved only when every check passes. Each hard task has a reference solution that passes and a
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
            score is the mean over tasks of each task&apos;s mean over its trials; every task weighs the same. A failed run counts as zero.
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
            we difference them per task and bootstrap the mean difference. Unpaired cells are dropped. That is the only comparison we draw
            conclusions from.
          </li>
          <li>
            <strong>Rule:</strong>{" "}if the 95% interval on a difference includes zero, the result is reported as too wide to call, whatever the
            point estimate is.
          </li>
        </ul>

        <h2 id="labels">What the labels mean</h2>
        <ul style={{ listStyle: "none", paddingLeft: 0 }}>
          <li>
            <Chip s="solid" /> The 95% interval on the claimed difference excludes zero. The direction is supported; the size may still be
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
            <Chip s="hist" /> An earlier write-up kept for the record; superseded by numbers computed from current data.
          </li>
        </ul>

        <h2 id="prereg">Preregistration and amendments</h2>
        <p>
          A study starts with a written question, model list, method, analysis and a stated expectation, fixed before the first episode. After
          that, every change is added as a dated amendment that records what had been observed when the change was made (for example: a toolset
          dropped after one pass showed it fails for a known reason; a bug fixed and which rows it touched). Rows run before a change are kept as
          they were and labelled, never silently rerun. Expectations that turn out wrong are reported as wrong.
        </p>

        <h2 id="explore">Exploration and the final pass</h2>
        <p>
          Exploration is where the harness gets debugged: one trial per task, fixes between runs, models dropped and added. Its numbers are a
          screen. The <em>final pass</em>{" "}then runs the shortlisted models on a frozen harness (hashed before the start), on fresh workspaces at
          a seed never used in exploration, with the analysis fixed in advance. Only final-pass numbers are presented as a ranking. A model&apos;s
          final score counts once its whole pass is done; partial passes show progress only.
        </p>

        <h2 id="bugs">Harness bug log</h2>
        <p>
          The tool-calling screen found twelve harness bugs in its first days; roughly half of the first day&apos;s failures were the harness, not
          the model. Each was fixed with a test before the final pass. We publish them because they generalise to any agent benchmark.
        </p>
        <ol className="buglog">
          {BUGS.map((b) => (
            <li key={b.t}>
              <span className="bt">{b.t}</span> {b.d}
              <span className="eff">Effect: {b.e}</span>
            </li>
          ))}
        </ol>
        <Note title="Lessons we now apply to every benchmark">
          <ul>
            <li>Score the end state, never the transcript.</li>
            <li>Read every failure before believing it.</li>
            <li>Check what a grammar-constrained decoder can and cannot emit.</li>
            <li>Jail code execution away from the answers, and test that it is jailed.</li>
            <li>Pin the clock of any simulated world.</li>
            <li>Give every checker a reference solution that passes and an untouched workspace that fails.</li>
          </ul>
        </Note>

        <h2 id="audit">The coding-suite rubric audit</h2>
        <p>
          An adversarial review of the coding suite found 26 rubrics that could award 100% to a non-working stub: an import error dropped the
          behavioural checks and collapsed the denominator, so a file containing only <code>x = 1</code>{" "}could pass. All 26 were rewritten so
          every check always emits (a stub now scores about 10%), and all 2,894 affected runs were re-scored. The same review found an unpaired
          harness comparison (a resume key that ignored the experiment tag), answer leakage in one task&apos;s comments, and best-of-trials
          aggregation; each was fixed, and every number on this site is from after the audit.
        </p>

        <h2 id="gaps">Known gaps</h2>
        <ul>
          <li>The coding-suite agent shell is not sandboxed; a model could read a rubric mid-run. Not observed.</li>
          <li>Coding-suite sampling used provider defaults; pinned temperature and seed are wired but not yet used for a full sweep.</li>
          <li>All tasks are ours. A standard external benchmark (Aider polyglot or SWE-bench-lite) is queued.</li>
          <li>The tool-calling harness is not public yet; its per-task rows are.</li>
        </ul>
        <p>
          See the <Link href="/data/">data</Link>{" "}page for the files every number is computed from.
        </p>
      </div>
    </>
  );
}
