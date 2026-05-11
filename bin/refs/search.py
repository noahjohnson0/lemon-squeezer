#!/usr/bin/env python3
"""search — query a corpus's FTS5 index and return ranked sections as JSON.

Used both as a CLI and imported by the librarian harness's tool.

Usage:
    bin/refs/search.py ~/refs/lemon-test "RTX 4070 CUDA cores"
    bin/refs/search.py ~/refs/wikipedia-en "haversine distance" --top 5
"""
from __future__ import annotations
import argparse, json, sqlite3, sys
from pathlib import Path

DEFAULT_TOP = 5


def search(corpus_dir: Path, query: str, top: int = DEFAULT_TOP) -> list[dict]:
    # ZIM-backed corpora (e.g. wikipedia-en) carry a .lemon-zim.conf sentinel and
    # are served by kiwix-serve; dispatch to the ZIM shim so `lemon search` works
    # uniformly across both backends. Same as the dispatch in bin/librarian.py.
    if (corpus_dir / ".lemon-zim.conf").exists():
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        from zim_search import search as zim_search  # type: ignore
        return zim_search(corpus_dir, query, top=top)
    db = corpus_dir / ".lemon-index.db"
    if not db.exists():
        raise FileNotFoundError(f"no index at {db}; build with bin/refs/build_index.py")
    conn = sqlite3.connect(db)
    cur = conn.execute(
        """
        SELECT path, title, section, body, rank
        FROM docs
        WHERE docs MATCH ?
        ORDER BY rank
        LIMIT ?
        """,
        (query, top),
    )
    out = []
    for path, title, section, body, rank in cur.fetchall():
        # Cap each body at 1500 chars so the model isn't drowned in context
        snippet = body[:1500] + ("…" if len(body) > 1500 else "")
        out.append({
            "path": path,
            "title": title,
            "section": section,
            "snippet": snippet,
            "rank": rank,
        })
    conn.close()
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("corpus_dir")
    p.add_argument("query")
    p.add_argument("--top", type=int, default=DEFAULT_TOP)
    p.add_argument("--json", action="store_true", help="raw JSON output")
    args = p.parse_args()
    results = search(Path(args.corpus_dir), args.query, args.top)
    if args.json:
        print(json.dumps(results, indent=2))
    else:
        for i, r in enumerate(results, 1):
            print(f"\n#{i}  {r['path']} :: {r['section']}")
            print("    " + r["snippet"][:200].replace("\n", "\n    "))


if __name__ == "__main__":
    main()
