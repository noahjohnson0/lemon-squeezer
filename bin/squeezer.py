#!/usr/bin/env python3
"""squeezer - a minimal raw-tool-calling harness.

Talks straight to an OpenAI-compatible Chat Completions endpoint (Ollama's /v1) with
the standard `tools` parameter. Implements four file/system tools:
  - read_file(path)
  - write_file(path, content)
  - list_files(dir)
  - run_bash(command, timeout=15)

Loops until the model emits no tool_calls or until --max-iter is reached.

We exist to A/B against pi and aider with a clean, no-magic baseline.
"""
from __future__ import annotations
import argparse, json, os, re, subprocess, sys, time, urllib.request, urllib.error
from pathlib import Path


# ───────────────────────── tool implementations ─────────────────────────
def make_tools(workspace: Path):
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
                out.append("…(truncated)")
                break
        return "\n".join(out) if out else "(empty)"

    def run_bash(command: str, timeout: int = 15) -> str:
        try:
            r = subprocess.run(
                ["bash", "-c", command],
                cwd=str(workspace),
                capture_output=True, text=True,
                timeout=timeout,
            )
            out = r.stdout[-4000:]
            err = r.stderr[-2000:]
            return f"exit={r.returncode}\nSTDOUT:\n{out}\nSTDERR:\n{err}"
        except subprocess.TimeoutExpired:
            return f"ERROR: timeout after {timeout}s"
        except Exception as e:
            return f"ERROR: {e!r}"

    return {"read_file": read_file, "write_file": write_file, "list_files": list_files, "run_bash": run_bash}


TOOLS_SCHEMA = [
    {"type": "function", "function": {
        "name": "read_file",
        "description": "Read a UTF-8 text file from the workspace. Returns 'ERROR: ...' on failure.",
        "parameters": {"type": "object", "required": ["path"],
                       "properties": {"path": {"type": "string", "description": "path relative to workspace"}}}
    }},
    {"type": "function", "function": {
        "name": "write_file",
        "description": "Write the given content to a workspace file (creates parent dirs). Replaces existing contents.",
        "parameters": {"type": "object", "required": ["path", "content"],
                       "properties": {"path": {"type": "string"}, "content": {"type": "string"}}}
    }},
    {"type": "function", "function": {
        "name": "list_files",
        "description": "List files (recursive) under a workspace directory. Returns 'd path' or 'f path' lines.",
        "parameters": {"type": "object", "properties": {"dir": {"type": "string", "default": "."}}}
    }},
    {"type": "function", "function": {
        "name": "run_bash",
        "description": "Run a bash command in the workspace cwd. Returns exit + stdout + stderr (last few KB). Default 15s timeout.",
        "parameters": {"type": "object", "required": ["command"],
                       "properties": {"command": {"type": "string"}, "timeout": {"type": "integer", "default": 15}}}
    }},
]


SYSTEM_PROMPT = """You are a coding agent. You operate on a project workspace via tools.
- Use list_files to discover what's there.
- Use read_file before editing any file you didn't write yourself in this session.
- Use write_file to create new files OR to fully replace existing ones (always send the COMPLETE new file content, not a partial diff).
- Use run_bash for syntax checks, unit tests, or running the produced code.
A successful tool result is NOT a stopping condition. After every tool result, decide the next step toward fully satisfying the user's request. Only stop when every requirement is addressed. When you stop, emit a final assistant message summarizing what you did."""


# ─────────────── text tool-call fallback (for local models) ───────────────
def parse_text_tool_calls(content: str):
    """Some models (esp. local ones via Ollama - qwen2.5-coder, etc.) emit tool
    calls as JSON *text* in the content instead of the native `tool_calls` field.
    Best-effort recover them so those models can still act as agents. Returns a
    list shaped like OpenAI tool_calls, or [] if none found. Native tool_calls
    always take precedence (this only runs when there are none)."""
    if not content:
        return []
    # Prefer fenced ```json ... ``` blocks; fall back to any balanced-looking object.
    blobs = re.findall(r"```(?:json|tool_call)?\s*(\{.*?\})\s*```", content, re.S)
    if not blobs:
        blobs = re.findall(r"(\{(?:[^{}]|\{[^{}]*\})*\})", content, re.S)
    calls = []
    for blob in blobs:
        try:
            obj = json.loads(blob)
        except Exception:
            continue
        if not isinstance(obj, dict):
            continue
        name = obj.get("name") or obj.get("tool") or (obj.get("function") or {}).get("name")
        args = obj.get("arguments")
        if args is None:
            args = obj.get("parameters")
        if args is None and isinstance(obj.get("function"), dict):
            args = obj["function"].get("arguments")
        if not name or args is None:
            continue
        calls.append({"id": f"text-{len(calls)}", "type": "function",
                      "function": {"name": name,
                                   "arguments": args if isinstance(args, str) else json.dumps(args)}})
    return calls


# ───────────────────────── HTTP layer (no deps) ─────────────────────────
def call_chat(base_url: str, model: str, messages, tools):
    url = base_url.rstrip("/") + "/chat/completions"
    body = json.dumps({"model": model, "messages": messages, "tools": tools, "stream": False}).encode()
    # Auth token: local Ollama ignores it ("ollama"); cloud OpenAI-compatible
    # endpoints (OpenRouter etc.) read it from $LEMON_API_KEY / $OPENROUTER_API_KEY.
    tok = os.environ.get("LEMON_API_KEY") or os.environ.get("OPENROUTER_API_KEY") or "ollama"
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {tok}"}
    # OpenRouter attribution headers (harmless elsewhere).
    if "openrouter.ai" in base_url:
        headers["HTTP-Referer"] = "https://github.com/noahjohnson0/lemon-squeezer"
        headers["X-Title"] = "lemon-squeezer"
    req = urllib.request.Request(url, data=body, headers=headers, method="POST")
    # Retry transient failures (connection timeouts under high concurrency, 429s,
    # 5xx). Don't retry real 4xx (bad request / auth / 402 no-credit).
    last = None
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=600) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 504) and attempt < 3:
                last = e; time.sleep(1.5 * (attempt + 1)); continue
            raise
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            if attempt < 3:
                last = e; time.sleep(1.5 * (attempt + 1)); continue
            raise
    raise last  # pragma: no cover


# ───────────────────────── main agent loop ─────────────────────────
def main():
    p = argparse.ArgumentParser()
    p.add_argument("--model", required=True)
    p.add_argument("--prompt-file", required=True)
    p.add_argument("--workspace", required=True)
    p.add_argument("--run-dir", required=True)
    p.add_argument("--base-url", default=(os.environ.get("OLLAMA_API_BASE") or "http://localhost:11434") + "/v1",
                   help="Override via $OLLAMA_API_BASE (e.g. http://192.168.x.x:11434 for a remote Ollama host)")
    p.add_argument("--max-iter", type=int, default=24)
    p.add_argument("--system", default=None,
                   help="Override the default system prompt with raw text or @path/to/file.md")
    args = p.parse_args()

    workspace = Path(args.workspace).resolve()
    run_dir = Path(args.run_dir).resolve()
    workspace.mkdir(parents=True, exist_ok=True)
    run_dir.mkdir(parents=True, exist_ok=True)

    tool_impls = make_tools(workspace)
    user_prompt = Path(args.prompt_file).read_text()

    # Tell the agent which files exist at start, since list_files is one tool call away anyway
    starter = "\n".join(f"  {p.relative_to(workspace)}" for p in sorted(workspace.rglob("*")) if p.is_file())
    if starter:
        user_prompt = f"{user_prompt}\n\n[workspace already contains:\n{starter}\n]"

    sys_prompt = SYSTEM_PROMPT
    if args.system:
        sys_prompt = Path(args.system[1:]).read_text() if args.system.startswith("@") else args.system
    messages = [
        {"role": "system", "content": sys_prompt},
        {"role": "user",   "content": user_prompt},
    ]

    transcript = []
    tot_in = tot_out = tot_calls = 0
    tot_cost = 0.0
    started = time.time()

    for it in range(args.max_iter):
        try:
            resp = call_chat(args.base_url, args.model, messages, TOOLS_SCHEMA)
        except urllib.error.HTTPError as e:
            transcript.append({"iter": it, "http_error": e.code, "body": e.read().decode("utf-8", "replace")[:400]})
            print(f"HTTP {e.code}", file=sys.stderr); break
        except Exception as e:
            transcript.append({"iter": it, "error": repr(e)})
            print(f"ERR {e!r}", file=sys.stderr); break

        u = resp.get("usage") or {}
        tot_in  += int(u.get("prompt_tokens", 0))
        tot_out += int(u.get("completion_tokens", 0))
        tot_cost += float(u.get("cost") or 0)  # OpenRouter reports usd cost per call

        choice = (resp.get("choices") or [{}])[0]
        msg = choice.get("message") or {}
        content    = msg.get("content") or ""
        tool_calls = msg.get("tool_calls") or []
        # Fallback: recover text-formatted tool calls from models that don't use
        # the native tool_calls field (common with local Ollama models).
        if not tool_calls and content:
            recovered = parse_text_tool_calls(content)
            if recovered:
                tool_calls = recovered

        # Echo to stdout for the harness shim's stdout.log
        if content:
            print(f"[ASSISTANT it={it}] {content[:300]}")
        for tc in tool_calls:
            print(f"[TOOL_CALL it={it}] {tc.get('function',{}).get('name')} {str(tc.get('function',{}).get('arguments'))[:200]}")

        # Append assistant message to history
        asst_msg = {"role": "assistant", "content": content}
        if tool_calls:
            asst_msg["tool_calls"] = tool_calls
        messages.append(asst_msg)

        # Stopping condition: no tool calls
        if not tool_calls:
            transcript.append({"iter": it, "final_content_chars": len(content)})
            break

        # Execute each tool call
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

    # Persist counters for the harness shim
    (run_dir / "tokens_in").write_text(str(tot_in))
    (run_dir / "tokens_out").write_text(str(tot_out))
    (run_dir / "tool_calls").write_text(str(tot_calls))
    (run_dir / "cost").write_text(f"{tot_cost:.6f}")

    # Persist a session log similar to pi's
    with (run_dir / "squeezer-session.jsonl").open("w") as f:
        for m in messages:
            f.write(json.dumps(m, default=str) + "\n")
    with (run_dir / "squeezer-trace.jsonl").open("w") as f:
        for r in transcript:
            f.write(json.dumps(r) + "\n")

    elapsed = time.time() - started
    print(f"\n[squeezer] done: {tot_calls} tools, {tot_in} in / {tot_out} out tokens, {elapsed:.1f}s")


if __name__ == "__main__":
    main()
