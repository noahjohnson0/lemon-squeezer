#!/usr/bin/env python3
"""squeezer-search — squeezer's coding tools + librarian's retrieval tools.

The hypothesis: a coding agent that can pull from cached docs (Python stdlib,
language refs) and optionally from the web should outperform a vanilla coding
agent on tasks where the model's parametric knowledge is shaky.

This is squeezer.py + search_local + read_local + (optional) web_search bolted
on. Same workspace contract, same write_file/read_file/run_bash, just more
context tools.

Usage:
  python3 bin/squeezer_search.py --model qwen3-coder:30b-a3b-q4_K_M \\
      --prompt-file ws/prompt.md --workspace ws --run-dir runs/X \\
      [--allow-web] [--max-iter 24]
"""
from __future__ import annotations
import argparse, json, os, subprocess, sys, time
import urllib.request, urllib.error, urllib.parse
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "refs"))
from search import search as fts_search  # type: ignore

# Re-use librarian's corpus parsing to keep things consistent
sys.path.insert(0, str(HERE))
from librarian import parse_corpora  # type: ignore


def make_tools(workspace: Path, corpora: dict[str, Path], allow_web: bool):
    def _safe(p: str) -> Path:
        ap = (workspace / p).resolve()
        if not str(ap).startswith(str(workspace.resolve())):
            raise ValueError(f"path escapes workspace: {p}")
        return ap

    def read_file(path: str) -> str:
        ap = _safe(path)
        if not ap.exists():
            return f"ERROR: no such file: {path}"
        try:
            return ap.read_text()
        except UnicodeDecodeError:
            return f"ERROR: binary file: {path}"

    def write_file(path: str, content: str) -> str:
        ap = _safe(path)
        ap.parent.mkdir(parents=True, exist_ok=True)
        ap.write_text(content)
        return f"OK: wrote {len(content)} bytes to {path}"

    def list_files(dir: str = ".") -> str:
        ap = _safe(dir)
        if not ap.exists():
            return f"ERROR: no such dir: {dir}"
        out = []
        for p in sorted(ap.rglob("*")):
            if any(part.startswith(".") for part in p.relative_to(ap).parts):
                continue
            rel = p.relative_to(workspace)
            out.append(f"{'d' if p.is_dir() else 'f'} {rel}")
            if len(out) >= 200:
                out.append("…(truncated)"); break
        return "\n".join(out) if out else "(empty)"

    def run_bash(command: str, timeout: int = 15) -> str:
        try:
            r = subprocess.run(
                ["bash", "-c", command],
                cwd=str(workspace), capture_output=True, text=True, timeout=timeout,
            )
            return f"exit={r.returncode}\nSTDOUT:\n{r.stdout[-4000:]}\nSTDERR:\n{r.stderr[-2000:]}"
        except subprocess.TimeoutExpired:
            return f"ERROR: timeout after {timeout}s"
        except Exception as e:
            return f"ERROR: {e!r}"

    def search_docs(query: str, corpus: str = "", top_k: int = 5) -> str:
        if not corpora:
            return "ERROR: no doc corpora configured"
        if not corpus:
            corpus = next(iter(corpora))
        if corpus not in corpora:
            return f"ERROR: unknown corpus '{corpus}'. Available: {list(corpora)}"
        try:
            hits = fts_search(corpora[corpus], query, top=int(top_k))
        except Exception as e:
            return f"ERROR: {e!r}"
        if not hits:
            return f"(no matches for '{query}' in '{corpus}')"
        return "\n\n---\n\n".join(
            f"[{i+1}] {corpus}::{h['path']} :: {h['section']}\n{h['snippet']}"
            for i, h in enumerate(hits)
        )

    def web_search(query: str, top_k: int = 5) -> str:
        if not allow_web:
            return "ERROR: web access disabled (offline mode)"
        url = "https://duckduckgo.com/html/?" + urllib.parse.urlencode({"q": query})
        req = urllib.request.Request(url, headers={"User-Agent": "lemon-squeezer-search/0.1"})
        try:
            with urllib.request.urlopen(req, timeout=15) as r:
                html = r.read().decode("utf-8", "replace")
        except Exception as e:
            return f"ERROR: {e!r}"
        import re
        hits = re.findall(r'class="result__a"[^>]*href="([^"]+)"[^>]*>([^<]+)</a>', html)
        if not hits:
            return "(no results)"
        return "\n".join(f"- {t.strip()}\n  {urllib.parse.unquote(h)}" for h, t in hits[: int(top_k)])

    return {
        "read_file": read_file, "write_file": write_file,
        "list_files": list_files, "run_bash": run_bash,
        "search_docs": search_docs, "web_search": web_search,
    }


def make_schema(corpora: dict[str, Path], allow_web: bool):
    corpus_names = list(corpora) or ["default"]
    s = [
        {"type": "function", "function": {
            "name": "read_file",
            "description": "Read a UTF-8 text file from the workspace.",
            "parameters": {"type": "object", "required": ["path"], "properties": {"path": {"type": "string"}}}
        }},
        {"type": "function", "function": {
            "name": "write_file",
            "description": "Write content to a workspace file (replaces existing).",
            "parameters": {"type": "object", "required": ["path", "content"],
                           "properties": {"path": {"type": "string"}, "content": {"type": "string"}}}
        }},
        {"type": "function", "function": {
            "name": "list_files",
            "description": "Recursively list workspace files.",
            "parameters": {"type": "object", "properties": {"dir": {"type": "string", "default": "."}}}
        }},
        {"type": "function", "function": {
            "name": "run_bash",
            "description": "Run a bash command in the workspace cwd. Default 15s timeout.",
            "parameters": {"type": "object", "required": ["command"],
                           "properties": {"command": {"type": "string"}, "timeout": {"type": "integer", "default": 15}}}
        }},
        {"type": "function", "function": {
            "name": "search_docs",
            "description": "Full-text search a local docs corpus (e.g. Python stdlib reference). Use BEFORE writing code that touches an unfamiliar API.",
            "parameters": {"type": "object", "required": ["query"], "properties": {
                "query": {"type": "string"},
                "corpus": {"type": "string", "enum": corpus_names},
                "top_k": {"type": "integer", "default": 5},
            }},
        }},
    ]
    if allow_web:
        s.append({"type": "function", "function": {
            "name": "web_search",
            "description": "Search the public web (DuckDuckGo). Returns title+URL only.",
            "parameters": {"type": "object", "required": ["query"], "properties": {
                "query": {"type": "string"}, "top_k": {"type": "integer", "default": 5},
            }},
        }})
    return s


SYSTEM_PROMPT = """You are a coding agent with access to a project workspace and to a local documentation corpus.

Tools:
- list_files / read_file / write_file / run_bash: operate on the workspace
- search_docs(query, corpus): retrieve relevant docs sections (use BEFORE writing code that calls APIs you're not 100% sure about)
- web_search: only present in online mode

Workflow:
1. list_files to orient.
2. read_file any starter files.
3. If the task involves a library/API you're unsure about, search_docs first. Cite the doc path in code comments.
4. write_file the implementation (full file, not a diff).
5. run_bash a quick syntax check or unit test.
6. Stop when done — emit a final summary message with no tool_calls.

Don't stop just because a tool succeeded — keep going until every requirement is covered."""


def call_chat(base_url, model, messages, tools):
    url = base_url.rstrip("/") + "/chat/completions"
    body = json.dumps({"model": model, "messages": messages, "tools": tools, "stream": False}).encode()
    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "Authorization": "Bearer ollama"}, method="POST")
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.loads(r.read())


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--model", required=True)
    p.add_argument("--prompt-file", required=True)
    p.add_argument("--workspace", required=True)
    p.add_argument("--run-dir", required=True)
    p.add_argument("--base-url", default=(os.environ.get("OLLAMA_API_BASE") or "http://localhost:11434") + "/v1")
    p.add_argument("--max-iter", type=int, default=24)
    p.add_argument("--allow-web", action="store_true")
    p.add_argument("--system", default=None)
    args = p.parse_args()

    workspace = Path(args.workspace).resolve()
    run_dir = Path(args.run_dir).resolve()
    workspace.mkdir(parents=True, exist_ok=True)
    run_dir.mkdir(parents=True, exist_ok=True)

    corpora = parse_corpora(os.environ.get("LEMON_CORPORA"), workspace)
    tool_impls = make_tools(workspace, corpora, args.allow_web)
    schema = make_schema(corpora, args.allow_web)

    user_prompt = Path(args.prompt_file).read_text()
    starter = "\n".join(f"  {p.relative_to(workspace)}" for p in sorted(workspace.rglob("*")) if p.is_file() and not any(s.startswith(".") for s in p.relative_to(workspace).parts))
    if starter:
        user_prompt = f"{user_prompt}\n\n[workspace already contains:\n{starter}\n]"
    if corpora:
        user_prompt += f"\n\n[available doc corpora: {list(corpora)}]"

    sys_prompt = SYSTEM_PROMPT
    if args.system:
        sys_prompt = Path(args.system[1:]).read_text() if args.system.startswith("@") else args.system
    messages = [{"role": "system", "content": sys_prompt}, {"role": "user", "content": user_prompt}]

    transcript = []; tot_in = tot_out = tot_calls = 0; started = time.time()
    for it in range(args.max_iter):
        try:
            resp = call_chat(args.base_url, args.model, messages, schema)
        except urllib.error.HTTPError as e:
            transcript.append({"iter": it, "http_error": e.code}); print(f"HTTP {e.code}", file=sys.stderr); break
        except Exception as e:
            transcript.append({"iter": it, "error": repr(e)}); print(f"ERR {e!r}", file=sys.stderr); break

        u = resp.get("usage") or {}
        tot_in += int(u.get("prompt_tokens", 0)); tot_out += int(u.get("completion_tokens", 0))
        choice = (resp.get("choices") or [{}])[0]; msg = choice.get("message") or {}
        content = msg.get("content") or ""; tool_calls = msg.get("tool_calls") or []

        if content: print(f"[ASSISTANT it={it}] {content[:300]}")
        for tc in tool_calls:
            print(f"[TOOL_CALL it={it}] {tc.get('function',{}).get('name')} {str(tc.get('function',{}).get('arguments'))[:200]}")

        asst_msg = {"role": "assistant", "content": content}
        if tool_calls: asst_msg["tool_calls"] = tool_calls
        messages.append(asst_msg)

        if not tool_calls:
            transcript.append({"iter": it, "final_content_chars": len(content)}); break

        for tc in tool_calls:
            tot_calls += 1
            fn = tc.get("function") or {}; name = fn.get("name", "")
            try:
                args_raw = fn.get("arguments") or "{}"
                if isinstance(args_raw, str): args_raw = json.loads(args_raw or "{}")
                if name not in tool_impls: result = f"ERROR: unknown tool {name}"
                else: result = tool_impls[name](**args_raw)
            except TypeError as e: result = f"ERROR: bad arguments: {e}"
            except Exception as e: result = f"ERROR: {e!r}"
            messages.append({"role": "tool", "tool_call_id": tc.get("id", ""), "content": str(result)[:8000]})
            transcript.append({"iter": it, "tool": name, "result_chars": len(str(result))})

    (run_dir / "tokens_in").write_text(str(tot_in))
    (run_dir / "tokens_out").write_text(str(tot_out))
    (run_dir / "tool_calls").write_text(str(tot_calls))
    with (run_dir / "squeezer-search-session.jsonl").open("w") as f:
        for m in messages: f.write(json.dumps(m, default=str) + "\n")
    with (run_dir / "squeezer-search-trace.jsonl").open("w") as f:
        for r in transcript: f.write(json.dumps(r) + "\n")
    print(f"\n[squeezer-search] done: {tot_calls} tools, {tot_in} in / {tot_out} out tokens, {time.time()-started:.1f}s")


if __name__ == "__main__":
    main()
