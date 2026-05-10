#!/usr/bin/env python3
"""squeezer-pipeline — multi-model orchestration on top of the squeezer agent loop.

Wires multiple agents in sequence — each step runs as its own model with its own
system prompt, but they share a single workspace. The classic recipe is
draft → critique → refine. We can also do propose → propose → propose → judge
(ensemble) by running multiple drafts and a final picker.

Usage examples:
  bin/squeezer_pipeline.py \
      --workspace /tmp/ws --run-dir /tmp/run --prompt-file PROMPT.md \
      --pipeline critique \
      --primary-model qwen3:14b \
      --critic-model gpt-oss:20b

  bin/squeezer_pipeline.py \
      --pipeline ensemble \
      --primary-model qwen3:14b,gpt-oss:20b,qwen3-coder:30b-a3b-q4_K_M \
      --judge-model gpt-oss:20b \
      ...
"""
from __future__ import annotations
import argparse, json, os, shutil, sys, time
from pathlib import Path

# Reuse squeezer's tool implementations + HTTP layer.
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import squeezer  # type: ignore

DRAFT_PROMPT = """You are a coding agent operating on a project workspace via tools.
Read the user's task carefully. Solve it end-to-end:
  - list_files to discover what's there
  - read_file before editing anything you didn't write yourself
  - write_file to create new files (always send the COMPLETE new file content)
  - run_bash to syntax-check and verify your work

After every tool result, ask whether the task is fully done. Only stop when
every requirement is addressed. Then emit a final assistant message summarising
what you wrote.
"""

CRITIC_PROMPT = """You are a strict, terse code reviewer. Another model just produced
files in this workspace to satisfy a user's task. Your job is to find what's wrong.

PROCEDURE:
  1. read the user's task (in the user message)
  2. list_files to see what was produced
  3. read_file each one
  4. run_bash to syntax-check or run quick smoke tests where possible
  5. emit a final message containing a numbered list of every defect:
     - missing requirement
     - bug, edge case, off-by-one
     - non-compiling code
     - incorrect output for plausible inputs
     - missing scaffolding / config / dep file

DO NOT WRITE OR MODIFY FILES. You have read/list/bash but not write.
DO NOT add preamble or apology — just the numbered list. If everything looks good,
say literally: "OK: nothing to fix" and stop.
"""

REFINE_PROMPT = """You wrote files in this workspace earlier to satisfy the user's task.
A reviewer found defects (below). Fix every defect. Use write_file to update the
relevant files (always with the COMPLETE new content, not a diff).

After making changes, run a final smoke test if possible (run_bash). Then emit a
short final message confirming what you changed.
"""

JUDGE_PROMPT = """You are a strict judge. Multiple coding agents each tried to solve
the user's task in a separate sub-workspace under candidates/. Read each candidate
(candidates/0, candidates/1, ...), determine which is most correct & complete, and
COPY ITS FILES into the top-level workspace using bash (cp/cp -R). Use the most
mechanical approach: 'cp -R candidates/<best>/. .'.

Do not author new files. Pick the best of what's there and promote it. Emit a final
message naming the candidate index you picked and one-sentence rationale.
"""

ARCHITECT_PROMPT = """You are a senior software architect. You do not write any code.
Read the user's task carefully. Emit a numbered plan, in plain text, that an executor
agent will follow line by line. Be specific:

  1. Name the file(s) to create and their exact purpose
  2. List the function/class signatures the executor must implement (signatures only — not bodies)
  3. For each function, state the algorithmic approach in 1-2 sentences (e.g. "use heapq with (cost, node) tuples", "Gauss-Jordan with partial pivoting")
  4. Call out edge cases the executor must handle
  5. Note any reference values to test against

Do NOT use any tools. Do NOT write code or files. Output ONLY the numbered plan as your assistant message."""

EXECUTOR_PROMPT = """You are an implementer working from a plan an architect handed you.
The plan is below in the user message. Implement it exactly:

  - Use list_files / read_file / write_file / run_bash as needed
  - Follow the architect's signatures and algorithmic guidance
  - Verify your work (syntax check + at least one quick run via run_bash) before stopping
  - If the plan has gaps, fill them with the simplest reasonable choice

Stop only when every step of the plan is implemented and you've verified it runs."""

VERIFY_PROMPT = """You are a careful coding agent who writes code AND property-based tests
for it in the same session. Procedure:

1. Identify the function/class signatures the user wants.
2. Write the implementation.
3. Write a tests file `test_<module>.py` that includes:
   - At least one happy-path case per function
   - At least one edge case
   - One PROPERTY test (e.g. round-trip: decode(encode(x)) == x; or invariant:
     after sort, output is non-decreasing AND length unchanged AND multiset preserved)
4. Run the tests via run_bash with `python3 -m pytest -x test_<module>.py 2>&1 | tail -20`.
5. If tests fail, fix the implementation OR the test (whichever is wrong) and re-run.
6. Stop only when all tests pass.

Tools: read_file, write_file, list_files, run_bash. Send COMPLETE file contents to write_file."""


def run_step(name: str, model: str, system_prompt: str, user_prompt: str,
             workspace: Path, run_dir: Path, base_url: str,
             max_iter: int = 12, allow_write: bool = True) -> dict:
    """Run one squeezer-style agent loop. Returns counters."""
    print(f"\n══════ STEP: {name}  ({model}) ══════", flush=True)
    tool_impls = squeezer.make_tools(workspace)
    if not allow_write:
        # Critic gets read-only tools
        def deny(*a, **kw): return "ERROR: this agent has no write access; describe defects in the final message."
        tool_impls = {**tool_impls, "write_file": deny}
    schema = list(squeezer.TOOLS_SCHEMA)
    if not allow_write:
        schema = [t for t in schema if t["function"]["name"] != "write_file"]

    # Tell the agent what's already there
    starter = "\n".join(
        f"  {p.relative_to(workspace)}" for p in sorted(workspace.rglob("*"))
        if p.is_file() and not any(part.startswith(".") for part in p.relative_to(workspace).parts)
    )
    msg_user = user_prompt + (f"\n\n[workspace already contains:\n{starter}\n]" if starter else "")
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user",   "content": msg_user},
    ]

    tot_in = tot_out = tot_calls = 0
    final_text = ""
    started = time.time()

    for it in range(max_iter):
        try:
            resp = squeezer.call_chat(base_url, model, messages, schema)
        except Exception as e:
            print(f"[{name}] HTTP error iter={it}: {e!r}", flush=True)
            break
        u = resp.get("usage") or {}
        tot_in  += int(u.get("prompt_tokens", 0))
        tot_out += int(u.get("completion_tokens", 0))
        msg = (resp.get("choices") or [{}])[0].get("message") or {}
        content    = msg.get("content") or ""
        tool_calls = msg.get("tool_calls") or []
        if content: print(f"[{name} it={it}] {content[:240]}", flush=True)
        for tc in tool_calls:
            print(f"[{name} it={it}] TOOL {tc.get('function',{}).get('name')} {str(tc.get('function',{}).get('arguments'))[:160]}", flush=True)
        asst = {"role": "assistant", "content": content}
        if tool_calls: asst["tool_calls"] = tool_calls
        messages.append(asst)
        if not tool_calls:
            final_text = content
            break
        for tc in tool_calls:
            tot_calls += 1
            fn = (tc.get("function") or {})
            tname = fn.get("name", "")
            try:
                args_raw = fn.get("arguments") or "{}"
                if isinstance(args_raw, str): args_raw = json.loads(args_raw or "{}")
                if tname not in tool_impls:
                    result = f"ERROR: unknown tool {tname}"
                else:
                    result = tool_impls[tname](**args_raw)
            except Exception as e:
                result = f"ERROR: {e!r}"
            messages.append({"role": "tool", "tool_call_id": tc.get("id",""), "content": str(result)[:8000]})

    # persist transcript per step
    with (run_dir / f"step-{name}.jsonl").open("w") as f:
        for m in messages: f.write(json.dumps(m, default=str) + "\n")

    elapsed = time.time() - started
    print(f"[{name}] done — {tot_calls} tools, {tot_in}/{tot_out} tok, {elapsed:.1f}s", flush=True)
    return {"name": name, "model": model, "tokens_in": tot_in, "tokens_out": tot_out,
            "tool_calls": tot_calls, "wall_s": round(elapsed, 1), "final": final_text}


def pipeline_architect(args, user_prompt: str, ws: Path, run_dir: Path) -> list[dict]:
    architect = args.architect_model or args.primary_model.split(",")[0]
    executor  = args.primary_model.split(",")[0]
    steps = []
    # Step 1: architect emits a plan as text (no tools — empty schema)
    plan_step = run_step("architect", architect, ARCHITECT_PROMPT, user_prompt, ws, run_dir,
                         args.base_url, allow_write=False, max_iter=2)
    steps.append(plan_step)
    plan = plan_step.get("final", "") or "(no plan emitted)"
    # Step 2: executor implements
    exec_input = f"{user_prompt}\n\n--- ARCHITECT PLAN ---\n{plan}\n\nImplement this plan now."
    steps.append(run_step("executor", executor, EXECUTOR_PROMPT, exec_input, ws, run_dir, args.base_url))
    return steps

def pipeline_verify(args, user_prompt: str, ws: Path, run_dir: Path) -> list[dict]:
    primary = args.primary_model.split(",")[0]
    return [run_step("verify", primary, VERIFY_PROMPT, user_prompt, ws, run_dir, args.base_url, max_iter=30)]

def pipeline_critique(args, user_prompt: str, ws: Path, run_dir: Path) -> list[dict]:
    primary = args.primary_model.split(",")[0]
    critic  = args.critic_model
    rounds  = args.rounds

    steps = []
    steps.append(run_step("draft", primary, DRAFT_PROMPT, user_prompt, ws, run_dir, args.base_url))
    for r in range(rounds):
        c = run_step(f"critique-{r+1}", critic, CRITIC_PROMPT, user_prompt, ws, run_dir, args.base_url, allow_write=False)
        steps.append(c)
        if "ok: nothing to fix" in (c.get("final") or "").lower():
            print(f"[pipeline] critic happy after round {r+1}; halting refinement", flush=True)
            break
        refine_input = (
            f"{user_prompt}\n\n--- REVIEWER FEEDBACK ---\n{c.get('final','')[:4000]}"
        )
        steps.append(run_step(f"refine-{r+1}", primary, REFINE_PROMPT, refine_input, ws, run_dir, args.base_url))
    return steps


def pipeline_ensemble(args, user_prompt: str, ws: Path, run_dir: Path) -> list[dict]:
    models = [m.strip() for m in args.primary_model.split(",") if m.strip()]
    judge = args.judge_model or models[0]
    steps = []
    candidates_root = ws / "candidates"
    candidates_root.mkdir(exist_ok=True)
    for i, m in enumerate(models):
        sub = candidates_root / str(i)
        sub.mkdir(exist_ok=True)
        # copy seed files into the sub
        for src in ws.iterdir():
            if src.is_dir() and src.name in ("candidates",): continue
            dst = sub / src.name
            if src.is_dir():
                if not dst.exists(): shutil.copytree(src, dst)
            else:
                shutil.copy2(src, dst)
        s = run_step(f"draft-{i}", m, DRAFT_PROMPT, user_prompt, sub, run_dir, args.base_url)
        s["candidate_dir"] = str(sub.relative_to(ws))
        steps.append(s)
    judge_user = (
        f"{user_prompt}\n\n"
        f"--- {len(models)} CANDIDATE SOLUTIONS ---\n"
        f"{len(models)} sub-workspaces under candidates/0..{len(models)-1}/. "
        f"Read each, evaluate against the task, and copy the BEST candidate's files "
        f"into the top-level workspace. Use bash 'cp -R candidates/<best>/. .' to do it."
    )
    steps.append(run_step("judge", judge, JUDGE_PROMPT, judge_user, ws, run_dir, args.base_url))
    return steps


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--workspace", required=True)
    p.add_argument("--run-dir", required=True)
    p.add_argument("--prompt-file", required=True)
    p.add_argument("--base-url", default=(os.environ.get("OLLAMA_API_BASE") or "http://localhost:11434") + "/v1")
    p.add_argument("--pipeline", choices=["critique", "ensemble", "architect", "verify"], required=True)
    p.add_argument("--primary-model", required=True, help="single model OR comma-separated for ensemble")
    p.add_argument("--critic-model",  default=None, help="critique pipeline only")
    p.add_argument("--judge-model",   default=None, help="ensemble pipeline only (defaults to first primary)")
    p.add_argument("--architect-model", default=None, help="architect pipeline only (defaults to primary)")
    p.add_argument("--rounds", type=int, default=1, help="critique pipeline: number of critique→refine cycles")
    args = p.parse_args()

    ws = Path(args.workspace).resolve()
    run_dir = Path(args.run_dir).resolve()
    ws.mkdir(parents=True, exist_ok=True)
    run_dir.mkdir(parents=True, exist_ok=True)
    user_prompt = Path(args.prompt_file).read_text()

    if args.pipeline == "critique":
        if not args.critic_model:
            print("--critic-model required for critique pipeline", file=sys.stderr); sys.exit(2)
        steps = pipeline_critique(args, user_prompt, ws, run_dir)
    elif args.pipeline == "ensemble":
        steps = pipeline_ensemble(args, user_prompt, ws, run_dir)
    elif args.pipeline == "architect":
        steps = pipeline_architect(args, user_prompt, ws, run_dir)
    elif args.pipeline == "verify":
        steps = pipeline_verify(args, user_prompt, ws, run_dir)
    else:
        print(f"unknown pipeline: {args.pipeline}", file=sys.stderr); sys.exit(2)

    tot_in = sum(s["tokens_in"] for s in steps)
    tot_out = sum(s["tokens_out"] for s in steps)
    tot_calls = sum(s["tool_calls"] for s in steps)
    (run_dir / "tokens_in").write_text(str(tot_in))
    (run_dir / "tokens_out").write_text(str(tot_out))
    (run_dir / "tool_calls").write_text(str(tot_calls))
    (run_dir / "pipeline-summary.json").write_text(json.dumps({
        "pipeline": args.pipeline,
        "steps": steps,
        "primary_model": args.primary_model,
        "critic_model": args.critic_model,
        "judge_model": args.judge_model,
        "rounds": args.rounds,
    }, indent=2))

    print(f"\n══════ PIPELINE DONE — {len(steps)} steps, {tot_in}/{tot_out} tok total ══════")


if __name__ == "__main__":
    main()
