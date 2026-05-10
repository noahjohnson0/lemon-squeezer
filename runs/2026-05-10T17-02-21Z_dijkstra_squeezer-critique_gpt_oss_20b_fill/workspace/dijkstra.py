"""Dijkstra's algorithm implementation.

This module exports a single function ``shortest_path`` that computes the
shortest path between two nodes in a directed graph with non‑negative edge
weights.  The graph is represented as a ``dict`` mapping node identifiers to
a ``list`` of ``(neighbour, weight)`` tuples.

The implementation is intentionally lightweight so it can be used in
educational contexts without pulling in heavyweight graph libraries.
"""

from __future__ import annotations

from heapq import heappush, heappop
from typing import Dict, List, Tuple


def shortest_path(
    graph: Dict[str, List[Tuple[str, float]]],
    src: str,
    dst: str,
) -> Tuple[float, List[str]]:
    """Compute the shortest path from *src* to *dst* using Dijkstra's algorithm.

    Parameters
    ----------
    graph:
        Dictionary mapping a node identifier to a list of ``(neighbor,
        weight)`` tuples.  All edge weights must be non‑negative.
    src, dst:
        Source and destination node identifiers.

    Returns
    -------
    tuple[float, list[str]]
        ``(total_distance, path)`` where *total_distance* is the sum of edge
        weights along the discovered path and *path* is a list of node ids
        from *src* to *dst* inclusive.  If no path exists ``(float('inf'),
        [])`` is returned.  If ``src == dst`` the function returns
        ``(0.0, [src])``.

    Notes
    -----
    * The implementation uses a binary heap (``heapq``) to maintain the
      frontier.  The complexity is ``O((V + E) log V)`` where ``V`` is the
      number of vertices and ``E`` the number of edges.
    * The function accepts a graph that may contain nodes with no outgoing
      edges; those are still considered part of the graph.
    * The function does **not** detect negative edge weights; the caller
      must ensure this invariant.
    """

    # Handle trivial cases first.
    if src == dst:
        return 0.0, [src]
    if src not in graph or dst not in graph:
        return float("inf"), []

    # Distance to each node: start with a big number; we only set when we
    # visit a neighbor.
    dist: Dict[str, float] = {src: 0.0}
    # Predecessor map to reconstruct path.
    prev: Dict[str, str] = {}

    # Priority queue of (distance, node).  We push the starting node.
    heap: List[Tuple[float, str]] = [(0.0, src)]
    visited: set[str] = set()

    while heap:
        cur_dist, u = heappop(heap)

        # Skip stale entries.
        if u in visited:
            continue
        visited.add(u)

        if u == dst:
            break

        for v, weight in graph.get(u, []):
            if weight < 0:
                raise ValueError("Negative edge weight detected; graph must be non‑negative.")
            new_dist = cur_dist + weight
            if new_dist < dist.get(v, float("inf")):
                dist[v] = new_dist
                prev[v] = u
                heappush(heap, (new_dist, v))

    if dst not in dist:
        # No path found.
        return float("inf"), []

    # Reconstruct path.
    path: List[str] = []
    cur = dst
    while cur != src:
        path.append(cur)
        cur = prev[cur]
    path.append(src)
    path.reverse()

    return dist[dst], path


# If run as a script, demonstrate the algorithm on a small graph.
if __name__ == "__main__":
    example_graph = {
        "A": [("B", 1.0), ("C", 4.0)],
        "B": [("C", 2.0), ("D", 5.0)],
        "C": [("D", 1.0)],
        "D": [],
    }
    d, p = shortest_path(example_graph, "A", "D")
    print(f"Shortest distance: {d}")
    print(f"Path: {p}")

