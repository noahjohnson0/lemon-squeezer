#!/usr/bin/env python3
"""zim_search - query a kiwix-serve instance as if it were a lemon corpus.

kiwix-serve (from kiwix-tools) exposes a ZIM file as HTTP. We hit:
  /search?books.name=<book>&pattern=<q>&pageLength=<n>   → JSON results
  /content/<book>/<path>                                  → article HTML

We use the JSON search endpoint (?search-format=json on newer builds, else
parse the HTML result page as a fallback). Article HTML is reduced to plain
text via a tiny heuristic stripper - no BeautifulSoup dependency.

Used by:
  - bin/refs/search.py (when corpus is registered as type=zim)
  - bin/librarian.py via the same search shim
  - bin/lemon search wiki "<query>" routes here if 'wiki' is a zim corpus

A 'zim corpus' is configured by a single-line text file at
<corpus_dir>/.lemon-zim.conf with content:

    base_url=http://svr:8080
    book=wikipedia_en_all_nopic_2026-03

(The 'book' is the URL-safe slug; kiwix-serve auto-derives it from the .zim
filename - usually the filename without the .zim extension.)

Usage as CLI:
    bin/refs/zim_search.py ~/refs/wikipedia-en "haversine distance" --top 5
"""
from __future__ import annotations
import argparse, html, json, re, sys, urllib.parse, urllib.request
from pathlib import Path


def _strip_html(s: str) -> str:
    s = re.sub(r"<script[^>]*>.*?</script>", " ", s, flags=re.DOTALL | re.IGNORECASE)
    s = re.sub(r"<style[^>]*>.*?</style>",   " ", s, flags=re.DOTALL | re.IGNORECASE)
    s = re.sub(r"<[^>]+>", " ", s)
    s = html.unescape(s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def _http_get(url: str, timeout: int = 20) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "lemon-zim/0.1", "Accept": "application/json, */*"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def read_conf(corpus_dir: Path) -> dict:
    conf = corpus_dir / ".lemon-zim.conf"
    if not conf.exists():
        raise FileNotFoundError(f"no zim conf at {conf} - create one with base_url=... and book=...")
    out = {}
    for line in conf.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"): continue
        if "=" not in line: continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip()
    if "base_url" not in out or "book" not in out:
        raise ValueError(f"{conf} must define base_url= and book=")
    return out


def search(corpus_dir: Path, query: str, top: int = 5, snippet_chars: int = 1500) -> list[dict]:
    """Return a list of hits matching the FTS5-search interface used elsewhere in lemon."""
    conf = read_conf(corpus_dir)
    base = conf["base_url"].rstrip("/")
    book = conf["book"]

    # Try the JSON-format endpoint first
    qs = urllib.parse.urlencode({"books.name": book, "pattern": query,
                                 "pageLength": top, "search-format": "json"})
    url = f"{base}/search?{qs}"
    try:
        body = _http_get(url)
        data = json.loads(body)
        results = data.get("results") or []
        out = []
        for r in results[:top]:
            path = r.get("path") or r.get("url") or ""
            title = r.get("title") or path.rsplit("/", 1)[-1]
            snippet = r.get("snippet") or ""
            if not snippet:
                # Fetch a bit of the article body to give the model some content
                try:
                    article = _http_get(f"{base}/content/{book}/{path}").decode("utf-8", "replace")
                    snippet = _strip_html(article)[:snippet_chars]
                except Exception:
                    pass
            out.append({
                "path": path, "title": title, "section": "(zim article)",
                "snippet": snippet[:snippet_chars],
                "rank": -1,  # kiwix doesn't expose a numeric rank; order is rank
            })
        return out
    except Exception:
        pass

    # HTML-page fallback: scrape the search-result anchors
    qs = urllib.parse.urlencode({"books.name": book, "pattern": query, "pageLength": top})
    url = f"{base}/search?{qs}"
    body = _http_get(url).decode("utf-8", "replace")
    anchors = re.findall(r'<a\s+href="([^"]+)"[^>]*>(.*?)</a>', body, flags=re.DOTALL)
    out = []
    for href, label in anchors:
        if "/content/" not in href: continue
        title = _strip_html(label)
        if not title: continue
        try:
            article = _http_get(href if href.startswith("http") else (base + href)).decode("utf-8", "replace")
            snippet = _strip_html(article)[:snippet_chars]
        except Exception:
            snippet = ""
        out.append({"path": href.split("/content/")[-1], "title": title, "section": "(zim article)",
                    "snippet": snippet, "rank": -1})
        if len(out) >= top: break
    return out


def read_article(corpus_dir: Path, path: str, max_chars: int = 12000) -> str:
    conf = read_conf(corpus_dir)
    base = conf["base_url"].rstrip("/")
    book = conf["book"]
    url = f"{base}/content/{book}/{path.lstrip('/')}"
    try:
        body = _http_get(url).decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return f"ERROR: HTTP {e.code} fetching {path}"
    except Exception as e:
        return f"ERROR: {e!r}"
    txt = _strip_html(body)
    if len(txt) > max_chars:
        txt = txt[:max_chars] + " …(truncated)"
    return txt


def main():
    p = argparse.ArgumentParser()
    p.add_argument("corpus_dir")
    p.add_argument("query")
    p.add_argument("--top", type=int, default=5)
    p.add_argument("--json", action="store_true")
    args = p.parse_args()
    results = search(Path(args.corpus_dir), args.query, args.top)
    if args.json:
        print(json.dumps(results, indent=2))
    else:
        for i, r in enumerate(results, 1):
            print(f"\n#{i}  {r['title']}  ({r['path']})")
            print("    " + r["snippet"][:280].replace("\n", "\n    "))


if __name__ == "__main__":
    main()
