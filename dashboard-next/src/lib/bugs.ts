// The tool-calling harness bug log. The count on the home page and Methods is BUGS.length.
export const BUGS: { t: string; d: string; e: string }[] = [
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
    d: "Editing a binary database or passing a non-string count raised an exception type the sandbox did not catch. The task then restarted from scratch in a new directory, which gave the model a hidden second attempt. Every tool exception now goes back to the model as a tool error.",
    e: "Made models look better",
  },
  {
    t: "Checkers crashed on bytecode caches.",
    d: "Models that imported their own code to test it left __pycache__ behind, and the checker crashed on it, so good behaviour was scored as a fail. Checkers skip bytecode and the Python sandbox no longer writes it.",
    e: "Made models look worse",
  },
  {
    t: "The system prompt called the agent a file manager.",
    d: "One model declined a refund-triage task because 'the tools available to me are limited to managing files'. The prompt now names the apps and says that nobody will answer questions, so the agent should state its assumptions and finish.",
    e: "Made models look worse",
  },
  {
    t: "Reasoning was off by default for one model.",
    d: "Its chat template defaults reasoning to none and the configuration never set it, so the model ran without reasoning. That row is labelled 'reasoning off'.",
    e: "Made one model look worse",
  },
  {
    t: "The largest model did not fit at the shared context length.",
    d: "At 131k context the 235B model ran out of memory. It ran at 65k with an 8-bit KV cache, so its rows are not on the same context as the others.",
    e: "Comparability",
  },
  {
    t: "The code sandbox could read the harness.",
    d: "run_python ran inside the worker container, which had the checkers, expected answers and reference solutions mounted read-only. A scan of every run_python call found no model touching a path outside its workspace. It now runs in a fresh container per call with only the workspace mounted, no network and a read-only root, with a test that the harness paths do not exist inside it.",
    e: "Could have made models look better",
  },
  {
    t: "The simulated world's date disagreed with the host clock.",
    d: "The mailbox and intranet are fixed at one date, and the host clock was weeks later. A model asked Python for today's date, computed '30 days ago' from the real date and archived the wrong newsletters. The prompt now states the world's date and the sandbox runs under a fake clock. The final pass restarted.",
    e: "Made models look worse",
  },
  {
    t: "Three checker bugs in the hardest suite.",
    d: "Two code checkers copied only part of the workspace, so a regression test that read a data file failed on a correct fix. One prompt named a policy file that was never created. A numbered '1. REFUSED:' line was not read as a refusal.",
    e: "Made models look worse",
  },
  {
    t: "Killed rows were counted as done.",
    d: "Rows interrupted when the model server was stopped mid-task were recorded as finished. They are now retried.",
    e: "Made models look worse",
  },
];
