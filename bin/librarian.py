#!/usr/bin/env python3
"""librarian — single-purpose RAG agent harness.

Modeled on squeezer.py but with a different toolset: instead of read/write/bash,
the agent gets retrieval tools over one or more local corpora (FTS5) plus an
optional web search. The point is to test how well a local model behaves as a
"librarian" — pull facts from references, ground answers, abstain when the
corpus doesn't contain the answer.

Tools exposed:
  - search_local(query, corpus="default", top_k=5)
  - read_local(path, corpus="default")
  - web_search(query, top_k=5)            # only if --allow-web
  - write_answer(text)                    # writes workspace/answer.txt and ENDS the loop

Corpora are passed in via $LEMON_CORPORA — colon-separated "name=path" pairs:
  LEMON_CORPORA="wiki=/Users/noahjohnson0/refs/lemon-test:py=/Users/noahjohnson0/refs/python-docs"

If --workspace/context/ exists, those files are added as an implicit corpus
named "context" (so wiki-rag-tool can drop hints there).

Usage:
  bin/librarian.py --model qwen3:14b --prompt-file ws/prompt.md \
      --workspace ws --run-dir runs/X
"""
from __future__ import annotations
import argparse, json, os, sqlite3, sys, time
import urllib.request, urllib.error, urllib.parse
from pathlib import Path

# Reuse the FTS5 search helper
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "refs"))
from search import search as fts_search  # type: ignore


# ───────────────────────── corpus registry ─────────────────────────
def parse_corpora(spec: str | None, workspace: Path) -> dict[str, Path]:
    """LEMON_CORPORA="name=path:name=path". An implicit 'context' corpus is added
    if workspace/context/ exists."""
    out: dict[str, Path] = {}
    if spec:
        for chunk in spec.split(":"):
            chunk = chunk.strip()
            if not chunk: continue
            if "=" not in chunk:
                print(f"[librarian] WARN: skipping malformed LEMON_CORPORA entry: {chunk}", file=sys.stderr)
                continue
            name, path = chunk.split("=", 1)
            out[name.strip()] = Path(path).expanduser().resolve()
    ctx = workspace / "context"
    if ctx.is_dir():
        # Build an on-the-fly index for workspace/context if not present
        if not (ctx / ".lemon-index.db").exists():
            from build_index import build  # type: ignore
            build(ctx, "context", verbose=False)
        out.setdefault("context", ctx)
    if not out:
        # Fallback: any corpus the user has registered locally
        default = Path.home() / "refs" / "lemon-test"
        if (default / ".lemon-index.db").exists():
            out["default"] = default
    return out


# ───────────────────────── tool implementations ─────────────────────────
def make_tools(workspace: Path, corpora: dict[str, Path], allow_web: bool):
    state = {"answer_written": False}

    def search_local(query: str, corpus: str = "", top_k: int = 5) -> str:
        if not corpora:
            return "ERROR: no corpora configured"
        if not corpus:
            corpus = next(iter(corpora))
        if corpus not in corpora:
            return f"ERROR: unknown corpus '{corpus}'. Available: {list(corpora)}"
        try:
            hits = fts_search(corpora[corpus], query, top=int(top_k))
        except sqlite3.OperationalError as e:
            return f"ERROR: bad query: {e}"
        if not hits:
            return f"(no matches for '{query}' in '{corpus}')"
        out = [f"[{i+1}] {corpus}::{h['path']} :: {h['section']}\n{h['snippet']}" for i, h in enumerate(hits)]
        return "\n\n---\n\n".join(out)

    def read_local(path: str, corpus: str = "") -> str:
        if not corpora:
            return "ERROR: no corpora configured"
        if not corpus:
            corpus = next(iter(corpora))
        if corpus not in corpora:
            return f"ERROR: unknown corpus '{corpus}'. Available: {list(corpora)}"
        target = (corpora[corpus] / path).resolve()
        if not str(target).startswith(str(corpora[corpus].resolve())):
            return f"ERROR: path escapes corpus: {path}"
        if not target.exists():
            return f"ERROR: no such file: {path}"
        try:
            text = target.read_text()
        except UnicodeDecodeError:
            return f"ERROR: binary file: {path}"
        # Cap to keep context manageable
        if len(text) > 8000:
            text = text[:8000] + "\n…(truncated)"
        return text

    def web_search(query: str, top_k: int = 5) -> str:
        if not allow_web:
            return "ERROR: web access disabled (this is offline mode)"
        # DuckDuckGo HTML — no API key, no JS. Best effort.
        url = "https://duckduckgo.com/html/?" + urllib.parse.urlencode({"q": query})
        req = urllib.request.Request(url, headers={"User-Agent": "lemon-librarian/0.1"})
        try:
            with urllib.request.urlopen(req, timeout=15) as r:
                html = r.read().decode("utf-8", "replace")
        except Exception as e:
            return f"ERROR: {e!r}"
        # Rough scrape — DDG result anchors
        import re
        hits = re.findall(r'class="result__a"[^>]*href="([^"]+)"[^>]*>([^<]+)</a>', html)
        if not hits:
            return "(no results)"
        out = []
        for href, title in hits[: int(top_k)]:
            href = urllib.parse.unquote(href)
            out.append(f"- {title.strip()}\n  {href}")
        return "\n".join(out)

    def write_answer(text: str) -> str:
        (workspace / "answer.txt").write_text(text)
        state["answer_written"] = True
        return f"OK: answer.txt ({len(text)} bytes). End of session — no further tool calls needed."

    return (
        {"search_local": search_local, "read_local": read_local, "web_search": web_search, "write_answer": write_answer},
        state,
    )


def make_schema(corpora: dict[str, Path], allow_web: bool) -> list[dict]:
    corpus_names = list(corpora) or ["default"]
    s: list[dict] = [
        {"type": "function", "function": {
            "name": "search_local",
            "description": "Full-text search a local reference corpus. Returns up to top_k ranked sections with their path and a snippet. Use to find specific facts in cached docs.",
            "parameters": {"type": "object", "required": ["query"], "properties": {
                "query": {"type": "string", "description": "FTS5 query (keywords, AND/OR/NOT, phrase \"...\" supported)"},
                "corpus": {"type": "string", "enum": corpus_names, "description": "Which corpus to search"},
                "top_k": {"type": "integer", "default": 5, "minimum": 1, "maximum": 20},
            }},
        }},
        {"type": "function", "function": {
            "name": "read_local",
            "description": "Read the full text of a corpus file (path is what search_local returned). Use when a snippet wasn't enough.",
            "parameters": {"type": "object", "required": ["path"], "properties": {
                "path": {"type": "string"},
                "corpus": {"type": "string", "enum": corpus_names},
            }},
        }},
        {"type": "function", "function": {
            "name": "write_answer",
            "description": "Write the FINAL answer to the user's question. Calling this ends the session — only call it once you have everything you need.",
            "parameters": {"type": "object", "required": ["text"], "properties": {"text": {"type": "string"}}},
        }},
    ]
    if allow_web:
        s.append({"type": "function", "function": {
            "name": "web_search",
            "description": "Search the public web (DuckDuckGo). Returns title + URL only — read_local cannot fetch URLs. Use sparingly; prefer search_local first.",
            "parameters": {"type": "object", "required": ["query"], "properties": {
                "query": {"type": "string"},
                "top_k": {"type": "integer", "default": 5},
            }},
        }})
    return s


SYSTEM_PROMPT = """You are a careful research librarian. You answer the user's questions ONLY using facts you retrieve from the available corpora.

Workflow:
1. Use search_local to find candidate sections. Try multiple queries if the first is unhelpful.
2. Use read_local to see a full document if a snippet was insufficient.
3. When a question's answer is not present in any corpus, say "I don't know — the available references don't contain this." Do NOT guess.
4. When you cite a fact, name the source filename in parentheses, e.g. "(rtx_4070.md)".
5. When you have a complete answer, call write_answer ONCE with the full final text. Do not call any tools after write_answer.

Be concise. Prefer numbers and short factual sentences over prose.
"""


# ───────────────────────── HTTP layer ─────────────────────────
def call_chat(base_url: str, model: str, messages, tools):
    url = base_url.rstrip("/") + "/chat/completions"
    body = json.dumps({"model": model, "messages": messages, "tools": tools, "stream": False}).encode()
    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "Authorization": "Bearer ollama"}, method="POST")
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.loads(r.read())


# ───────────────────────── main agent loop ─────────────────────────
def main():
    p = argparse.ArgumentParser()
    p.add_argument("--model", required=True)
    p.add_argument("--prompt-file", required=True)
    p.add_argument("--workspace", required=True)
    p.add_argument("--run-dir", required=True)
    p.add_argument("--base-url", default=(os.environ.get("OLLAMA_API_BASE") or "http://localhost:11434") + "/v1")
    p.add_argument("--max-iter", type=int, default=16)
    p.add_argument("--allow-web", action="store_true", help="enable web_search tool")
    p.add_argument("--system", default=None, help="raw text or @path/to/file.md")
    args = p.parse_args()

    workspace = Path(args.workspace).resolve()
    run_dir   = Path(args.run_dir).resolve()
    workspace.mkdir(parents=True, exist_ok=True)
    run_dir.mkdir(parents=True, exist_ok=True)

    corpora = parse_corpora(os.environ.get("LEMON_CORPORA"), workspace)
    if not corpora:
        print("[librarian] WARN: no corpora available — search_local will always error", file=sys.stderr)

    tool_impls, state = make_tools(workspace, corpora, args.allow_web)
    schema = make_schema(corpora, args.allow_web)

    user_prompt = Path(args.prompt_file).read_text()
    if corpora:
        manifest = "\n".join(f"  - {name} ({sum(1 for _ in p.rglob('*.md'))} markdown docs)" for name, p in corpora.items())
        user_prompt = f"{user_prompt}\n\n[available corpora:\n{manifest}\n]"

    sys_prompt = SYSTEM_PROMPT
    if args.system:
        sys_prompt = Path(args.system[1:]).read_text() if args.system.startswith("@") else args.system
    messages = [
        {"role": "system", "content": sys_prompt},
        {"role": "user",   "content": user_prompt},
    ]

    transcript = []
    tot_in = tot_out = tot_calls = 0
    started = time.time()

    # Write counters incrementally so a SIGTERM/SIGKILL (e.g. eval-run gtimeout)
    # doesn't erase what we've already accumulated. The harness will pick up
    # whatever's most-recent in these files.
    def _flush_counters():
        try:
            (run_dir / "tokens_in").write_text(str(tot_in))
            (run_dir / "tokens_out").write_text(str(tot_out))
            (run_dir / "tool_calls").write_text(str(tot_calls))
        except Exception:
            pass

    for it in range(args.max_iter):
        try:
            resp = call_chat(args.base_url, args.model, messages, schema)
        except urllib.error.HTTPError as e:
            transcript.append({"iter": it, "http_error": e.code, "body": e.read().decode("utf-8", "replace")[:400]})
            print(f"HTTP {e.code}", file=sys.stderr); break
        except Exception as e:
            transcript.append({"iter": it, "error": repr(e)})
            print(f"ERR {e!r}", file=sys.stderr); break

        u = resp.get("usage") or {}
        tot_in  += int(u.get("prompt_tokens", 0))
        tot_out += int(u.get("completion_tokens", 0))
        _flush_counters()

        choice = (resp.get("choices") or [{}])[0]
        msg = choice.get("message") or {}
        content    = msg.get("content") or ""
        tool_calls = msg.get("tool_calls") or []

        if content:
            print(f"[ASSISTANT it={it}] {content[:300]}")
        for tc in tool_calls:
            print(f"[TOOL_CALL it={it}] {tc.get('function',{}).get('name')} {str(tc.get('function',{}).get('arguments'))[:200]}")

        asst_msg = {"role": "assistant", "content": content}
        if tool_calls:
            asst_msg["tool_calls"] = tool_calls
        messages.append(asst_msg)

        if not tool_calls:
            transcript.append({"iter": it, "final_content_chars": len(content)})
            # If the model produced a final message but never called write_answer,
            # treat its last content as the answer (graceful fallback).
            if not state["answer_written"] and content.strip():
                (workspace / "answer.txt").write_text(content)
                state["answer_written"] = True
            break

        for tc in tool_calls:
            tot_calls += 1
            fn = (tc.get("function") or {})
            name = fn.get("name", "")
            try:
                args_raw = fn.get("arguments") or "{}"
                if isinstance(args_raw, str):
                    args_raw = json.loads(args_raw or "{}")
                if name not in tool_impls:
                    result = f"ERROR: unknown tool {name}"
                else:
                    result = tool_impls[name](**args_raw)
            except TypeError as e:
                result = f"ERROR: bad arguments: {e}"
            except Exception as e:
                result = f"ERROR: {e!r}"

            messages.append({
                "role": "tool",
                "tool_call_id": tc.get("id", ""),
                "content": str(result)[:8000],
            })
            transcript.append({"iter": it, "tool": name, "args_keys": list(args_raw.keys()) if isinstance(args_raw, dict) else None, "result_chars": len(str(result))})

        # Early exit: write_answer terminates the agent
        if state["answer_written"]:
            transcript.append({"iter": it, "early_exit": "write_answer"})
            break

    _flush_counters()  # final flush

    with (run_dir / "librarian-session.jsonl").open("w") as f:
        for m in messages:
            f.write(json.dumps(m, default=str) + "\n")
    with (run_dir / "librarian-trace.jsonl").open("w") as f:
        for r in transcript:
            f.write(json.dumps(r) + "\n")

    elapsed = time.time() - started
    print(f"\n[librarian] done: {tot_calls} tools, {tot_in} in / {tot_out} out tokens, {elapsed:.1f}s, answer={'yes' if state['answer_written'] else 'NO'}")


if __name__ == "__main__":
    main()
