#!/usr/bin/env python3
"""librarian-cascade - two-model RAG pipeline.

Phase 1 (RETRIEVER): a small/fast model loops with `search_local` and
`read_local`, gathering relevant passages. It cannot answer - its job is to
collect evidence. Stops when it produces a turn with no tool calls or when
$CASCADE_RETRIEVER_BUDGET searches are exhausted (default 8).

Phase 2 (ANSWERER): a big/strong model receives:
  - the original user prompt
  - the concatenated retrieved sections (from phase 1)
…and is asked to write the final answer. It does NOT have search tools - it
must reason from what was retrieved. This forces the big model to be a faithful
synthesizer rather than re-running the search itself.

The split lets us pair a cheap planner (qwen3:8b ~ 5GB) with an expensive
synthesizer (command-r:35b ~ 18GB) and pay big-model cost only for the
synthesis turn. In the limit it's a poor-man's speculative-decoding-meets-RAG.

Usage (matches librarian shim contract):
  python3 bin/librarian_cascade.py \\
      --retriever qwen3:8b --answerer command-r:35b \\
      --prompt-file ws/prompt.md --workspace ws --run-dir runs/X

Env:
  CASCADE_RETRIEVER_BUDGET  max iters for phase 1 (default 8)
  LEMON_CORPORA             same as librarian.py
"""
from __future__ import annotations
import argparse, json, os, sys, time
import urllib.request, urllib.error
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "refs"))
from librarian import parse_corpora, make_tools as make_lib_tools, make_schema as make_lib_schema, call_chat  # type: ignore


RETRIEVER_SYSTEM = """You are the RETRIEVAL phase of a two-stage librarian pipeline.

Your ONE job: find passages that will help answer the user's question. You do
NOT write the final answer - that's a different model's job.

Tools: search_local, read_local. Try multiple queries with different keywords
(synonyms, narrower/broader terms). Aim for breadth.

Stop when you've gathered enough - emit a single short summary message with
no tool calls. Do not call write_answer (it's not available here)."""

ANSWERER_SYSTEM = """You are the SYNTHESIS phase of a two-stage librarian pipeline. A retriever has already gathered relevant passages - they are appended to the user's question below.

Use ONLY the retrieved passages. If they don't contain a fact, say "I don't know - the retrieved references don't contain this." Cite the source filename in parentheses.

Be concise. Do not call any tools - just write the final answer text."""


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--retriever", required=True, help="small/fast model (qwen3:8b is a good default)")
    p.add_argument("--answerer",  required=True, help="big/strong model (command-r:35b for librarian, gpt-oss:20b also good)")
    p.add_argument("--prompt-file", required=True)
    p.add_argument("--workspace", required=True)
    p.add_argument("--run-dir", required=True)
    p.add_argument("--base-url", default=(os.environ.get("OLLAMA_API_BASE") or "http://localhost:11434") + "/v1")
    p.add_argument("--max-iter", type=int, default=int(os.environ.get("CASCADE_RETRIEVER_BUDGET", "8")))
    args = p.parse_args()

    workspace = Path(args.workspace).resolve()
    run_dir = Path(args.run_dir).resolve()
    workspace.mkdir(parents=True, exist_ok=True); run_dir.mkdir(parents=True, exist_ok=True)

    corpora = parse_corpora(os.environ.get("LEMON_CORPORA"), workspace)

    # Phase 1 tools - ONLY search/read, no write_answer (we're harvesting evidence)
    tool_impls, _state = make_lib_tools(workspace, corpora, allow_web=False)
    # Drop write_answer / web_search from the schema for the retriever phase
    schema = [t for t in make_lib_schema(corpora, allow_web=False)
              if t["function"]["name"] in ("search_local", "read_local")]
    user_prompt = Path(args.prompt_file).read_text()

    messages = [
        {"role": "system", "content": RETRIEVER_SYSTEM},
        {"role": "user",   "content": user_prompt},
    ]
    transcript = []
    tot_in_r = tot_out_r = tot_calls = 0
    retrieved: list[str] = []  # accumulated tool results - this is what gets passed to phase 2

    started = time.time()
    for it in range(args.max_iter):
        try:
            resp = call_chat(args.base_url, args.retriever, messages, schema)
        except Exception as e:
            transcript.append({"phase": "retriever", "iter": it, "error": repr(e)}); break

        u = resp.get("usage") or {}
        tot_in_r += int(u.get("prompt_tokens", 0)); tot_out_r += int(u.get("completion_tokens", 0))
        msg = (resp.get("choices") or [{}])[0].get("message") or {}
        content = msg.get("content") or ""; tool_calls = msg.get("tool_calls") or []

        if content: print(f"[RETRIEVER it={it}] {content[:200]}")
        for tc in tool_calls:
            print(f"[RET_TOOL it={it}] {tc.get('function',{}).get('name')} {str(tc.get('function',{}).get('arguments'))[:160]}")

        asst = {"role": "assistant", "content": content}
        if tool_calls: asst["tool_calls"] = tool_calls
        messages.append(asst)

        if not tool_calls:
            transcript.append({"phase": "retriever", "iter": it, "stop": "no_tool_calls"})
            break

        for tc in tool_calls:
            tot_calls += 1
            fn = tc.get("function") or {}; name = fn.get("name", "")
            try:
                args_raw = fn.get("arguments") or "{}"
                if isinstance(args_raw, str): args_raw = json.loads(args_raw or "{}")
                if name not in tool_impls or name not in {"search_local", "read_local"}:
                    result = f"ERROR: tool {name} not allowed in retrieval phase"
                else:
                    result = tool_impls[name](**args_raw)
            except TypeError as e: result = f"ERROR: bad arguments: {e}"
            except Exception as e: result = f"ERROR: {e!r}"
            messages.append({"role": "tool", "tool_call_id": tc.get("id", ""), "content": str(result)[:6000]})
            transcript.append({"phase": "retriever", "iter": it, "tool": name, "result_chars": len(str(result))})
            # Accumulate the retrieved evidence (only successful searches)
            if isinstance(result, str) and not result.startswith("ERROR"):
                retrieved.append(f"## tool={name} args={json.dumps(args_raw, default=str)}\n\n{result}")

    # ───── Phase 2: ANSWERER ─────
    evidence = "\n\n---\n\n".join(retrieved) if retrieved else "(no passages were retrieved)"
    user_prompt_2 = (
        f"{user_prompt}\n\n"
        f"=== Retrieved passages (use these only) ===\n\n{evidence}\n\n"
        f"=== End of retrieved passages ===\n\n"
        f"Now write the final answer."
    )
    messages2 = [
        {"role": "system", "content": ANSWERER_SYSTEM},
        {"role": "user",   "content": user_prompt_2},
    ]
    tot_in_a = tot_out_a = 0
    final_text = ""
    try:
        resp = call_chat(args.base_url, args.answerer, messages2, [])  # no tools in phase 2
        u = resp.get("usage") or {}
        tot_in_a += int(u.get("prompt_tokens", 0)); tot_out_a += int(u.get("completion_tokens", 0))
        msg = (resp.get("choices") or [{}])[0].get("message") or {}
        final_text = msg.get("content") or ""
        print(f"\n[ANSWERER] {final_text[:300]}")
    except Exception as e:
        transcript.append({"phase": "answerer", "error": repr(e)})
        print(f"[ANSWERER ERR] {e!r}", file=sys.stderr)

    if final_text.strip():
        (workspace / "answer.txt").write_text(final_text)

    # Persist totals - eval-run picks these up
    (run_dir / "tokens_in").write_text(str(tot_in_r + tot_in_a))
    (run_dir / "tokens_out").write_text(str(tot_out_r + tot_out_a))
    (run_dir / "tool_calls").write_text(str(tot_calls))
    # Cascade-specific breakdown
    (run_dir / "cascade-stats.json").write_text(json.dumps({
        "retriever_model": args.retriever, "answerer_model": args.answerer,
        "retriever_in": tot_in_r, "retriever_out": tot_out_r,
        "answerer_in": tot_in_a, "answerer_out": tot_out_a,
        "tool_calls": tot_calls, "evidence_sections": len(retrieved),
    }, indent=2))
    with (run_dir / "cascade-trace.jsonl").open("w") as f:
        for r in transcript: f.write(json.dumps(r) + "\n")

    elapsed = time.time() - started
    print(f"\n[cascade] retriever={args.retriever} ({tot_in_r}+{tot_out_r} tok, {tot_calls} tools), "
          f"answerer={args.answerer} ({tot_in_a}+{tot_out_a} tok), "
          f"evidence={len(retrieved)} sections, {elapsed:.1f}s, answer={'yes' if final_text else 'NO'}")


if __name__ == "__main__":
    main()
