Write `dijkstra.py` exporting:

```python
def shortest_path(graph: dict[str, list[tuple[str, float]]], src: str, dst: str) -> tuple[float, list[str]]:
    """Compute the shortest path from src to dst in a weighted directed graph.

    graph: {node_id: [(neighbour_id, weight), ...]} - edges have non-negative weights.
    Returns (total_distance, [src, ..., dst]).
    If no path exists, returns (float('inf'), []).
    If src == dst, returns (0.0, [src])."""
```

Use a priority queue (`heapq`). Standard Dijkstra. No third-party graph libs.

Create only `dijkstra.py`. Don't run it.
