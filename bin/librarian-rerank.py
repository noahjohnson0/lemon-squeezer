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

# Reuse the FTS5 search helper, plus the ZIM-via-kiwix-serve backend
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "refs"))
from search import search as fts_search  # type: ignore
from zim_search import search as zim_search, read_article as zim_read  # type: ignore


def _is_zim_corpus(corpus_dir: Path) -> bool:
    """A corpus is treated as ZIM-backed if it has a .lemon-zim.conf file."""
    return (corpus_dir / ".lemon-zim.conf").exists()


def _dispatch_search(corpus_dir: Path, query: str, top: int = 5):
    """Pick FTS5 or ZIM backend based on which marker files are present."""
    if _is_zim_corpus(corpus_dir):
        return zim_search(corpus_dir, query, top=top)
    return fts_search(corpus_dir, query, top=top)


# ───────────────────────── embedding rerank helper ─────────────────────────
# We use Ollama's /api/embed batch endpoint with nomic-embed-text. Cheap (~50ms
# for 30 short texts on the 4070). The rerank is what bridges the vocabulary
# gap between question wording and article wording — the bottleneck the
# FTS-only librarian couldn't cross.

EMBED_MODEL = os.environ.get("LEMON_EMBED_MODEL", "nomic-embed-text")


def _embed_batch(texts: list, base_url: str, model: str = EMBED_MODEL) -> list:
    """POST /api/embed with input=[...]; return list of vectors."""
    if not texts:
        return []
    body = json.dumps({"model": model, "input": [t[:2000] for t in texts]}).encode()
    base = base_url.rstrip("/v").rstrip("/")  # strip /v1 if present; we need /api/embed
    url = base + "/api/embed"
    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        d = json.loads(r.read())
    return d.get("embeddings", [])


def _cosine(a: list, b: list) -> float:
    import math
    if not a or not b:
        return 0.0
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a)) or 1.0
    nb = math.sqrt(sum(x * x for x in b)) or 1.0
    return dot / (na * nb)


def _ollama_base_for_embed(librarian_base_url: str) -> str:
    """The librarian gets --base-url ending in /v1 (OpenAI-compat). Strip /v1
    for the native Ollama /api/embed endpoint."""
    u = librarian_base_url.rstrip("/")
    if u.endswith("/v1"):
        u = u[: -len("/v1")]
    return u


# ───────────────────────── LLM-as-reranker (listwise) ─────────────────────────
# Published technique: instead of (or after) cosine rerank, have an LLM read
# all top-K candidates and listwise-rank them by relevance to the question.
# Cross-encoder-style reasoning at the whole-candidate-set level. Reported
# lift on RAGAS: +15-30pp over embedding-only rerank. We do it AFTER cosine
# rerank to keep candidate count tractable.
#
# Uses a small fast model (gemma4:e4b) so the reranking call adds ~5-10s,
# not the ~25s of the answering model. Single LLM call, listwise output.

RERANK_MODEL = os.environ.get("LEMON_RERANK_MODEL", "gemma4:e4b")

_RERANK_PROMPT = """You are a relevance ranker. Given a QUESTION and a list of CANDIDATE snippets, identify which snippets contain (or strongly imply) the answer.

QUESTION: {question}

CANDIDATES:
{candidates}

Return ONLY a JSON array of the candidate indices (0-based) sorted by relevance, most relevant first. Include only candidates that plausibly help answer the question (cap at {top_k}). If multiple snippets are equally good, prefer the one with specific numeric values or named entities directly answering the question. Do NOT include reasoning, just the JSON array.

Example output: [3, 7, 0, 5]

JSON array:"""


def _llm_rerank(question: str, candidates: list, top_k: int, model: str, base_url: str,
                timeout_s: int = 45) -> list:
    """Listwise LLM rerank. Returns candidates reordered by LLM judgment.
    On any failure, returns the original list unchanged (graceful degradation)."""
    if not candidates or len(candidates) <= top_k:
        return candidates[:top_k]
    cand_text = "\n".join(
        f"[{i}] {c['_corpus']}: {c['snippet'][:400]}" for i, c in enumerate(candidates)
    )
    prompt = _RERANK_PROMPT.format(question=question, candidates=cand_text, top_k=top_k)
    try:
        body = json.dumps({
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "stream": False,
            "max_tokens": 120,
        }).encode()
        url = base_url.rstrip("/") + "/chat/completions"
        req = urllib.request.Request(url, data=body, headers={
            "Content-Type": "application/json",
            "Authorization": "Bearer ollama",
        })
        with urllib.request.urlopen(req, timeout=timeout_s) as r:
            d = json.loads(r.read())
        text = (d.get("choices", [{}])[0].get("message", {}).get("content") or "").strip()
        import re
        m = re.search(r"\[\s*(?:\d+\s*,?\s*)+\]", text)
        if not m:
            return candidates[:top_k]
        idxs = json.loads(m.group(0))
        seen = set()
        reordered = []
        for i in idxs:
            i = int(i)
            if 0 <= i < len(candidates) and i not in seen:
                seen.add(i)
                reordered.append(candidates[i])
            if len(reordered) >= top_k:
                break
        # Pad if LLM returned fewer than top_k.
        if len(reordered) < top_k:
            for i, c in enumerate(candidates):
                if i not in seen:
                    reordered.append(c)
                    if len(reordered) >= top_k:
                        break
        return reordered
    except Exception:
        return candidates[:top_k]


def _strip_book_prefix(path: str, corpus_dir: Path) -> str:
    """zim_search returns paths like 'book_name/Article' but zim_read's URL
    builder prepends the book again. Defensively strip ALL prefix variants
    the model might invent. We see in the wild:
      'wikipedia-en::Portable_water_purification'          ← corpus::slug
      'wikipedia_en_all_nopic_2026-03/Portable_water_...'  ← book/slug
      'wikipedia-en_all_nopic_2026-03/Portable_water_...'  ← hallucinated mix
      'Portable_water_purification'                         ← the correct one
    Strategy: drop anything before the first '::' or '/' if either is present.
    Kiwix article URLs are flat under their book root (internal slashes
    in article titles are URL-encoded as %2F) so this is always safe.
    """
    if not _is_zim_corpus(corpus_dir):
        return path
    # Strip 'something::' prefix
    if "::" in path:
        path = path.split("::", 1)[1]
    # Strip 'something/' prefix
    if "/" in path:
        path = path.split("/", 1)[1]
    return path


_FTS_STOPWORDS = set(
    "a an and as at be but by do does for from how i if in into is it its like "
    "may my much no not of on one only or over per say so some such than that "
    "the their them then there these they this those to use was way we what "
    "when where which while who why will with would you your".split()
)


def _question_tokens(question: str) -> list:
    import re
    q = re.sub(r"\([^)]*\)", " ", question)
    q = re.sub(r"[^A-Za-z0-9.\-]+", " ", q)
    out = []
    for tok in q.split():
        low = tok.lower().strip(".-")
        if not low or low in _FTS_STOPWORDS or len(low) < 2:
            continue
        out.append(tok)
    return out


def _question_to_fts_variants(question: str) -> list:
    """Generate 2-3 keyword query variants from a natural-language question.
    Different variants have different recall profiles — long-keyword for
    distinctiveness, short-keyword for breadth — and the union typically
    finds the right article even when a single variant misses."""
    tokens = _question_tokens(question)
    if not tokens:
        return [question[:80]]
    variants = []
    # Variant 1: all content tokens (up to 12)
    variants.append(" ".join(tokens[:12]))
    # Variant 2: top 4-5 by length (proxy for distinctiveness — longer
    # words tend to be more specific / less common)
    by_len = sorted(set(tokens), key=lambda t: -len(t))
    if len(by_len) >= 3:
        variants.append(" ".join(by_len[:5]))
    # Variant 3: first 3 content tokens (often topic-defining)
    if len(tokens) >= 3:
        variants.append(" ".join(tokens[:3]))
    # Deduplicate while preserving order
    seen = set(); out = []
    for v in variants:
        if v in seen: continue
        seen.add(v); out.append(v)
    return out


# Backwards-compat alias used elsewhere
def _question_to_fts_query(question: str) -> str:
    v = _question_to_fts_variants(question)
    return v[0] if v else question


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
def make_tools(workspace: Path, corpora: dict[str, Path], allow_web: bool,
               embed_base: str = "", rerank_base: str = ""):
    state = {"answer_written": False}

    def search_local(query: str, corpus: str = "", top_k: int = 5) -> str:
        if not corpora:
            return "ERROR: no corpora configured"
        if not corpus:
            corpus = next(iter(corpora))
        if corpus not in corpora:
            return f"ERROR: unknown corpus '{corpus}'. Available: {list(corpora)}"
        try:
            hits = _dispatch_search(corpora[corpus], query, top=int(top_k))
        except sqlite3.OperationalError as e:
            return f"ERROR: bad query: {e}"
        except Exception as e:
            return f"ERROR: search failed: {e!r}"
        if not hits:
            return f"(no matches for '{query}' in '{corpus}')"
        out = [f"[{i+1}] {corpus}::{h['path']} :: {h['section']}\n{h['snippet']}" for i, h in enumerate(hits)]
        return "\n\n---\n\n".join(out)

    def search_multi(queries: list, corpora_list: list = None, top_k_per_query: int = 3) -> str:
        """Multi-query expansion: run several search queries across one or more
        corpora and return the deduplicated, interleaved top results. This is
        the big lever for RAG recall — passing 3-5 paraphrased queries across
        the right corpora typically lifts retrieval accuracy by 10-20pp."""
        if not corpora:
            return "ERROR: no corpora configured"
        if not isinstance(queries, list) or not queries:
            return "ERROR: queries must be a non-empty list of strings"
        # Default: search ALL corpora if caller didn't pick a subset
        target = list(corpora.keys()) if not corpora_list else [c for c in corpora_list if c]
        unknown = [c for c in target if c not in corpora]
        if unknown:
            return f"ERROR: unknown corpora {unknown}. Available: {list(corpora)}"
        if not target:
            target = list(corpora.keys())
        # Run each (query × corpus) pair and dedup by (corpus, path)
        seen = set()
        results = []
        for q in [str(x) for x in queries[:6]]:  # cap queries at 6
            for c in target:
                try:
                    hits = _dispatch_search(corpora[c], q, top=int(top_k_per_query))
                except Exception:
                    continue
                for h in hits:
                    key = (c, h["path"])
                    if key in seen:
                        continue
                    seen.add(key)
                    results.append({**h, "_corpus": c, "_query": q})
        if not results:
            qs = ", ".join(f'"{x}"' for x in queries[:6])
            cs = ", ".join(target[:6]) + ("…" if len(target) > 6 else "")
            return f"(no matches for any of [{qs}] across [{cs}])"
        # Cap output to 20 results so the context doesn't blow up
        out = []
        for i, h in enumerate(results[:20]):
            out.append(
                f"[{i+1}] {h['_corpus']}::{h['path']} :: {h.get('section', '')}\n"
                f"     (matched via query: \"{h['_query']}\")\n"
                f"{h['snippet']}"
            )
        n_results = len(results)
        suffix = f"\n\n(showing top 20 of {n_results} unique hits)" if n_results > 20 else ""
        return "\n\n---\n\n".join(out) + suffix

    def search_semantic(question: str, corpora_list: list = None,
                        top_fts_per_corpus: int = 4, top_rerank: int = 8) -> str:
        """Hybrid retrieval: FTS5 keyword fan-out across corpora, then EMBEDDING
        rerank using nomic-embed-text. This bridges the vocabulary gap that
        single-query FTS5 can't cross — "EPA bleach water disinfection" won't
        match "Household chlorine treatment for emergency drinking water" by
        keyword, but their embeddings are close. Typical published lift over
        FTS-only is +20-40pp on factoid retrieval.

        Returns the top_rerank snippets sorted by question↔snippet cosine
        similarity, with their per-corpus path so the model can read_local.
        """
        if not corpora:
            return "ERROR: no corpora configured"
        if not embed_base:
            return "ERROR: embedding base URL not configured (set in main())"
        if not isinstance(question, str) or not question.strip():
            return "ERROR: question must be a non-empty string"
        target = list(corpora.keys()) if not corpora_list else [c for c in corpora_list if c]
        unknown = [c for c in target if c not in corpora]
        if unknown:
            return f"ERROR: unknown corpora {unknown}. Available: {list(corpora)}"
        if not target:
            target = list(corpora.keys())

        # Stage 1: FTS5 fan-out across target corpora WITH multiple query
        # variants. FTS keyword match is sensitive to which content word
        # appears in the article title; running 2-3 variants (full, longest,
        # first-3-content-words) gives much better recall before we even
        # rerank.
        fts_variants = _question_to_fts_variants(question)
        seen_paths = set()
        candidates = []
        for c in target:
            for fq in fts_variants:
                try:
                    hits = _dispatch_search(corpora[c], fq, top=int(top_fts_per_corpus))
                except Exception:
                    continue
                for h in hits:
                    key = (c, h["path"])
                    if key in seen_paths:
                        continue
                    seen_paths.add(key)
                    candidates.append({**h, "_corpus": c, "_fts_query": fq})
        if not candidates:
            qs = " | ".join(f"'{q}'" for q in fts_variants)
            return f"(no FTS candidates across {len(target)} corpora for any of: {qs})"

        # Stage 2: Batch-embed question + all candidate snippets in one call.
        try:
            all_texts = [question] + [c["snippet"][:1800] for c in candidates]
            embs = _embed_batch(all_texts, embed_base)
        except Exception as e:
            return f"ERROR: embedding failed: {e!r}. (FTS candidates: {len(candidates)})"
        if len(embs) != len(all_texts):
            return f"ERROR: embedding returned {len(embs)} vectors, expected {len(all_texts)}"
        q_emb = embs[0]
        snippet_embs = embs[1:]

        # Stage 3: Cosine rerank (first stage).
        scored = [(_cosine(q_emb, e), c) for e, c in zip(snippet_embs, candidates)]
        scored.sort(key=lambda x: -x[0])

        # Stage 3b: LLM listwise rerank (second stage).
        # Take the cosine top-K + some extra candidates (broader pool for the
        # LLM to consider) and let the LLM pick the truly relevant ones.
        # This is the cross-encoder-style intervention that published research
        # shows lifts RAG accuracy by 15-30pp on RAGAS.
        cosine_pool_size = min(int(top_rerank) + 12, len(scored))
        cosine_pool = [c for _, c in scored[:cosine_pool_size]]
        if rerank_base and len(cosine_pool) > int(top_rerank):
            try:
                cosine_pool = _llm_rerank(question, cosine_pool, int(top_rerank),
                                          model=RERANK_MODEL, base_url=rerank_base)
            except Exception:
                pass  # graceful fallback to cosine-only

        # Stage 4: Render top_rerank with similarity scores.
        # For LLM-reranked results, sim score is the original cosine.
        # Strip the book-name prefix from the displayed path so the model
        # passes the right slug to read_local (zim_read prepends the book).
        # Recompute sim scores by re-pairing with embeddings for display.
        cand_to_sim = {id(c): s for s, c in scored}
        top = [(cand_to_sim.get(id(c), 0.0), c) for c in cosine_pool[: int(top_rerank)]]
        out = []
        for i, (sim, h) in enumerate(top):
            display_path = _strip_book_prefix(h["path"], corpora[h["_corpus"]])
            out.append(
                f"[{i+1}] (sim={sim:.3f}) corpus={h['_corpus']} path={display_path}\n"
                f"{h['snippet']}"
            )
        # Note: tried auto-inlining the top-1 article body here; reverted
        # because the top-1 by cosine is sometimes a BROAD overview article
        # (sim ~0.65) rather than the SPECIFIC one with the factoid, and
        # injecting 6KB of overview text distracts the model into writing
        # general essays instead of extracting the requested fact. The
        # snippet-only output below is empirically better.
        suffix = f"\n\n(reranked top {len(top)} of {len(candidates)} FTS candidates across {len(target)} corpora)"
        return "\n\n---\n\n".join(out) + suffix

    def read_local(path: str, corpus: str = "") -> str:
        if not corpora:
            return "ERROR: no corpora configured"
        if not corpus:
            corpus = next(iter(corpora))
        if corpus not in corpora:
            return f"ERROR: unknown corpus '{corpus}'. Available: {list(corpora)}"
        corpus_dir = corpora[corpus]
        # ZIM-backed: fetch the article from kiwix-serve.
        # Defensively strip a leading book-name prefix — the model sometimes
        # includes it from memory even though search_semantic now shows the
        # bare slug.
        if _is_zim_corpus(corpus_dir):
            path = _strip_book_prefix(path, corpus_dir)
            try:
                return zim_read(corpus_dir, path)
            except Exception as e:
                return f"ERROR: zim fetch failed: {e!r}"
        # FTS5-backed: read the file relative to corpus dir
        target = (corpus_dir / path).resolve()
        if not str(target).startswith(str(corpus_dir.resolve())):
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
        {
            "search_local": search_local,
            "search_multi": search_multi,
            "search_semantic": search_semantic,
            "read_local": read_local,
            "web_search": web_search,
            "write_answer": write_answer,
        },
        state,
    )


def make_schema(corpora: dict[str, Path], allow_web: bool) -> list[dict]:
    corpus_names = list(corpora) or ["default"]
    s: list[dict] = [
        {"type": "function", "function": {
            "name": "search_local",
            "description": "Full-text search a SINGLE local reference corpus with ONE query. Returns up to top_k ranked sections with their path and a snippet. Prefer search_multi for new questions (better recall via paraphrase + cross-corpus); use search_local only when you've already found a relevant path and want to drill deeper.",
            "parameters": {"type": "object", "required": ["query"], "properties": {
                "query": {"type": "string", "description": "FTS5 query (keywords, AND/OR/NOT, phrase \"...\" supported)"},
                "corpus": {"type": "string", "enum": corpus_names, "description": "Which corpus to search"},
                "top_k": {"type": "integer", "default": 5, "minimum": 1, "maximum": 20},
            }},
        }},
        {"type": "function", "function": {
            "name": "search_semantic",
            "description": "STRONGLY PREFERRED for new questions. Hybrid retrieval: FTS5 keyword fan-out across corpora + EMBEDDING RERANK using a local embedding model (nomic-embed-text). This bridges the vocabulary gap between question wording and article wording that FTS alone cannot — 'EPA bleach water disinfection' will find articles titled 'Household chlorine for emergency drinking water' because their embeddings are close. Returns snippets sorted by question↔snippet cosine similarity with a sim= score per result. Slower than search_local (~1-3s overhead per call) but dramatically better recall.",
            "parameters": {"type": "object", "required": ["question"], "properties": {
                "question": {"type": "string", "description": "The question or topic you're researching. Use natural language — the embedder handles paraphrase."},
                "corpora_list": {"type": "array", "items": {"type": "string", "enum": corpus_names},
                                 "description": "Optional subset of corpora to search. If omitted, searches ALL configured corpora — usually right for a first attempt."},
                "top_fts_per_corpus": {"type": "integer", "default": 4, "minimum": 1, "maximum": 10},
                "top_rerank": {"type": "integer", "default": 8, "minimum": 1, "maximum": 20},
            }},
        }},
        {"type": "function", "function": {
            "name": "search_multi",
            "description": "PREFERRED retrieval entrypoint. Multi-query, multi-corpus search: pass 3-5 PARAPHRASED queries (synonyms, technical vs. lay terms, narrow vs. broad) and optionally a subset of corpora; returns the deduplicated, interleaved best hits. This dramatically improves recall when a single FTS query would miss the answer because of vocabulary mismatch.",
            "parameters": {"type": "object", "required": ["queries"], "properties": {
                "queries": {"type": "array", "items": {"type": "string"},
                            "description": "3-5 paraphrased search queries. Make them DIVERSE — synonyms, technical-vs-lay, narrow-vs-broad. Example: ['EPA bleach water disinfection', 'sodium hypochlorite drinking water dose', 'emergency water purification chlorine ratio']."},
                "corpora_list": {"type": "array", "items": {"type": "string", "enum": corpus_names},
                                 "description": "Optional subset of corpora. If omitted or empty, searches ALL configured corpora — usually the right default for a first attempt."},
                "top_k_per_query": {"type": "integer", "default": 3, "minimum": 1, "maximum": 10},
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

CRITICAL RETRIEVAL STRATEGY:
You have a HYBRID retrieval tool, search_semantic, that does FTS5 keyword search across every corpus AND reranks the candidates by embedding similarity to your question. This bridges the vocabulary gap that pure keyword search can't cross.

Your FIRST action on almost every question should be search_semantic with the original question phrased naturally. The embedder handles paraphrase — you don't need to think up synonyms.

Example — question: "How long should I boil cloudy water at sea level to make it safe to drink?"
  GOOD: search_semantic(question="how long boil cloudy water to make it safe to drink at sea level")
  BAD:  search_local(query="boil water") — too narrow, will miss articles using different wording

Workflow:
1. FIRST CALL — search_semantic with the question phrased naturally. Look at the sim= scores; sim ≥ 0.65 is usually a strong match, sim ≥ 0.55 is plausible, sim < 0.50 is shaky.
2. If a top-ranked snippet contains the answer, skip directly to write_answer.
3. If no snippet is sufficient (top sim too low or snippets don't contain the specific fact), call read_local on the 1-3 most-promising articles to see the full text. The path comes from the search result line (looks like "corpus::path") — pass JUST the path part to read_local with corpus="<corpus_name>".
4. If a question's answer is truly absent across every relevant corpus even after reading the most-promising articles, say "I don't know — the available references don't contain this." Do NOT guess from prior knowledge.
5. When you cite a fact, put the corpus::path slug in parentheses, e.g. "(wikipedia-en::Standard_gravity)". Do NOT add a .md / .html suffix — these are kiwix-served articles, not markdown files.
6. When you have a complete answer, call write_answer ONCE with the full final text. Do not call any tools after write_answer.

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

    tool_impls, state = make_tools(workspace, corpora, args.allow_web,
                                   embed_base=_ollama_base_for_embed(args.base_url),
                                   rerank_base=args.base_url)
    schema = make_schema(corpora, args.allow_web)

    user_prompt = Path(args.prompt_file).read_text()
    if corpora:
        # Describe each corpus honestly. ZIM-backed corpora (kiwix-serve) have
        # millions of articles but no on-disk .md files, so the old md-count
        # path lied with "0 markdown docs" and models like qwen3 abstained
        # without ever calling search_local. Use the corpus type instead.
        def _describe(name, p):
            if (p / ".lemon-zim.conf").exists():
                return f"  - {name} (ZIM corpus via kiwix-serve; use search_local to query)"
            n_md = sum(1 for _ in p.rglob("*.md"))
            if n_md:
                return f"  - {name} ({n_md} markdown docs; use search_local)"
            return f"  - {name} (corpus; use search_local)"
        manifest = "\n".join(_describe(name, p) for name, p in corpora.items())
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
                # 16K chars (~4K tokens) so search_semantic's snippets PLUS
                # the auto-inlined top article fit. Modern Ollama context
                # windows (qwen3:14b: 32K+, gemma4:e4b: 8K+) handle this.
                "content": str(result)[:16000],
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
