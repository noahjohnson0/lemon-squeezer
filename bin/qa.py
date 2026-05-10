#!/usr/bin/env python3
"""qa — single-turn / RAG-turn harness for non-agentic evals.

Reads a prompt with a special structure (see below), sends ONE chat-completion
to the OpenAI-compatible endpoint, writes the model's text response into the
workspace as `answer.txt`. The eval rubric scores `answer.txt`.

Optional RAG mode: if the eval workspace contains a `context/` directory with
files in it, those files are concatenated into a system message before the
user prompt. This is the "librarian" pattern — the agent has retrieved
documents and must answer faithfully from them.

Prompt file format (no special syntax — entire file becomes the user message
unless these fences appear):

    <<<system
    You are a helpful research assistant. Cite sources by filename.
    >>>

    What is the population of Tokyo according to the documents?

If `<<<system ... >>>` appears, those lines become the system message; the
rest is the user message. (Normal markdown is fine — only that exact marker
is special.)
"""
from __future__ import annotations
import argparse, json, os, re, sys, time, urllib.error, urllib.request
from pathlib import Path

SYSTEM_RE = re.compile(r"<<<system\n(.*?)\n>>>\n?", re.DOTALL)
DEFAULT_SYSTEM = (
    "You are a careful research assistant. Answer the user's question. "
    "If retrieved context documents are provided, ONLY use facts present in "
    "them — never invent. If the answer isn't in the context, say 'I don't "
    "know' and stop. When you cite a fact, name the source filename."
)


def call_chat(base_url: str, model: str, messages: list, timeout_s: int = 300) -> dict:
    url = base_url.rstrip("/") + "/chat/completions"
    body = json.dumps({"model": model, "messages": messages, "stream": False}).encode()
    req = urllib.request.Request(
        url,
        data=body,
        headers={"Content-Type": "application/json", "Authorization": "Bearer ollama"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout_s) as r:
        return json.loads(r.read())


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--model", required=True)
    p.add_argument("--prompt-file", required=True)
    p.add_argument("--workspace", required=True)
    p.add_argument("--run-dir", required=True)
    p.add_argument(
        "--base-url",
        default=(os.environ.get("OLLAMA_API_BASE") or "http://localhost:11434") + "/v1",
    )
    p.add_argument("--timeout", type=int, default=300)
    args = p.parse_args()

    workspace = Path(args.workspace).resolve()
    run_dir = Path(args.run_dir).resolve()
    workspace.mkdir(parents=True, exist_ok=True)
    run_dir.mkdir(parents=True, exist_ok=True)

    raw = Path(args.prompt_file).read_text()
    sys_match = SYSTEM_RE.search(raw)
    if sys_match:
        system_msg = sys_match.group(1).strip()
        user_msg = SYSTEM_RE.sub("", raw, count=1).strip()
    else:
        system_msg = DEFAULT_SYSTEM
        user_msg = raw.strip()

    # RAG layer: if workspace/context/ exists, prepend its files into the system msg.
    ctx_dir = workspace / "context"
    if ctx_dir.is_dir():
        chunks = []
        for f in sorted(ctx_dir.iterdir()):
            if f.is_file():
                try:
                    chunks.append(f"=== {f.name} ===\n{f.read_text()}")
                except Exception:
                    continue
        if chunks:
            system_msg = (
                f"{system_msg}\n\n"
                f"Retrieved context documents are below. Use these as your source of truth.\n\n"
                + "\n\n".join(chunks)
            )

    messages = [
        {"role": "system", "content": system_msg},
        {"role": "user", "content": user_msg},
    ]

    started = time.time()
    try:
        resp = call_chat(args.base_url, args.model, messages, args.timeout)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")[:500]
        print(f"[qa] HTTP {e.code}: {body}", file=sys.stderr)
        (workspace / "answer.txt").write_text(f"ERROR: HTTP {e.code}")
        sys.exit(0)
    except Exception as e:
        print(f"[qa] error: {e!r}", file=sys.stderr)
        (workspace / "answer.txt").write_text(f"ERROR: {e!r}")
        sys.exit(0)
    elapsed = time.time() - started

    msg = (resp.get("choices") or [{}])[0].get("message") or {}
    text = msg.get("content") or ""
    (workspace / "answer.txt").write_text(text)

    usage = resp.get("usage") or {}
    (run_dir / "tokens_in").write_text(str(int(usage.get("prompt_tokens", 0))))
    (run_dir / "tokens_out").write_text(str(int(usage.get("completion_tokens", 0))))
    (run_dir / "tool_calls").write_text("0")  # qa is single-turn, no tool calls

    # Persist the conversation for inspection
    transcript = {
        "messages": messages + [{"role": "assistant", "content": text}],
        "elapsed_s": round(elapsed, 2),
        "usage": usage,
    }
    (run_dir / "qa-transcript.json").write_text(json.dumps(transcript, indent=2))
    print(f"[qa] {len(text)} chars · {usage.get('prompt_tokens',0)}/{usage.get('completion_tokens',0)} tok · {elapsed:.1f}s")


if __name__ == "__main__":
    main()
