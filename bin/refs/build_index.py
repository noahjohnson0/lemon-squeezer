#!/usr/bin/env python3
"""build_index — turn a directory of text/markdown into a SQLite FTS5 index.

Each top-level file under <corpus_dir>/ becomes a "document". Markdown headings
become section breaks (so retrieval can return a relevant section, not the whole
file). For now we keep it simple: split on H1/H2/H3 headings.

Output: <corpus_dir>/.lemon-index.db (FTS5 virtual table 'docs').

Schema:
    docs(path, title, section, body)   # FTS5 over (title, section, body)
    meta(corpus_name, built_at, n_docs, n_sections)

Usage:
    bin/refs/build_index.py ~/refs/lemon-test
    bin/refs/build_index.py ~/refs/wikipedia-en --corpus wikipedia
"""
from __future__ import annotations
import argparse, re, sqlite3, sys, time
from pathlib import Path

# Markdown heading split (H1/H2/H3). Anything not under a heading is "preamble".
HEAD_RE = re.compile(r"^(#{1,3})\s+(.+?)\s*$", re.MULTILINE)


def split_sections(text: str) -> list[tuple[str, str]]:
    """Yield (section_title, section_body) tuples. First chunk before any heading
    is labelled 'preamble'."""
    parts = []
    matches = list(HEAD_RE.finditer(text))
    if not matches:
        return [("preamble", text.strip())]
    if matches[0].start() > 0:
        parts.append(("preamble", text[: matches[0].start()].strip()))
    for i, m in enumerate(matches):
        title = m.group(2).strip()
        start = m.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        body = text[start:end].strip()
        parts.append((title, body))
    return [(t, b) for t, b in parts if b]


def build(corpus_dir: Path, corpus_name: str | None = None, verbose: bool = True) -> dict:
    if not corpus_dir.is_dir():
        raise SystemExit(f"not a directory: {corpus_dir}")
    db_path = corpus_dir / ".lemon-index.db"
    if db_path.exists():
        db_path.unlink()
    conn = sqlite3.connect(db_path)
    conn.executescript(
        """
        CREATE VIRTUAL TABLE docs USING fts5(
            path, title, section, body,
            tokenize='porter unicode61 remove_diacritics 2'
        );
        CREATE TABLE meta (
            key TEXT PRIMARY KEY,
            value TEXT
        );
        """
    )
    n_docs, n_sections = 0, 0
    for path in sorted(corpus_dir.rglob("*")):
        if path.is_dir(): continue
        if path.suffix.lower() not in {".md", ".txt", ".rst"}: continue
        if path.name.startswith("."): continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        rel = str(path.relative_to(corpus_dir))
        title = rel.rsplit("/", 1)[-1].rsplit(".", 1)[0].replace("_", " ")
        sections = split_sections(text)
        for sec_title, body in sections:
            if not body.strip(): continue
            conn.execute(
                "INSERT INTO docs(path, title, section, body) VALUES (?, ?, ?, ?)",
                (rel, title, sec_title, body),
            )
            n_sections += 1
        n_docs += 1
        if verbose: print(f"  indexed {rel} ({len(sections)} sections)")
    conn.execute("INSERT INTO meta(key,value) VALUES('corpus', ?)", (corpus_name or corpus_dir.name,))
    conn.execute("INSERT INTO meta(key,value) VALUES('built_at', ?)", (time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),))
    conn.execute("INSERT INTO meta(key,value) VALUES('n_docs', ?)", (str(n_docs),))
    conn.execute("INSERT INTO meta(key,value) VALUES('n_sections', ?)", (str(n_sections),))
    conn.commit()
    conn.close()
    if verbose:
        print(f"\n→ {db_path}")
        print(f"  docs={n_docs}  sections={n_sections}")
    return {"db": str(db_path), "n_docs": n_docs, "n_sections": n_sections}


def main():
    p = argparse.ArgumentParser()
    p.add_argument("corpus_dir")
    p.add_argument("--corpus", help="logical name (default: dir basename)")
    p.add_argument("-q", "--quiet", action="store_true")
    args = p.parse_args()
    build(Path(args.corpus_dir), args.corpus, verbose=not args.quiet)


if __name__ == "__main__":
    main()
