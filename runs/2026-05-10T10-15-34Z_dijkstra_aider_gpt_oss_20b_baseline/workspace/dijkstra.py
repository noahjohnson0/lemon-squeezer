import heapq
from typing import Dict, List, Tuple

def shortest_path(
    graph: Dict[str, List[Tuple[str, float]]],
    src: str,
    dst: str
) -> Tuple[float, List[str]]:
    """
    Compute the shortest path from src to dst in a weighted directed graph.

    Parameters
    ----------
    graph : dict[str, list[tuple[str, float]]]
        Mapping of node identifiers to a list of (neighbour_id, weight) tuples.
        All edge weights must be non-negative.
    src : str
        Identifier of the source node.
    dst : str
        Identifier of the destination node.

    Returns
    -------
    tuple[float, list[str]]
        A tuple containing:
        - total_distance : float
            The sum of the weights along the shortest path.
            If no path exists, this is float('inf').
        - path : list[str]
            The list of node identifiers from src to dst inclusive.
            If no path exists, this is an empty list.
            If src == dst, returns (0.0, [src]).
    """
    # Edge case: source and destination are the same
    if src == dst:
        return 0.0, [src]

    # Initialize distances and priority queue
    distances: Dict[str, float] = {node: float('inf') for node in graph}
    distances[src] = 0.0
    prev: Dict[str, str] = {}

    # Priority queue holds tuples of (distance, node)
    heap: List[Tuple[float, str]] = [(0.0, src)]
    visited: set[str] = set()

    while heap:
        current_dist, current_node = heapq.heappop(heap)

        # Skip if we have already processed this node
        if current_node in visited:
            continue
        visited.add(current_node)

        # If we reached the destination, we can stop early
        if current_node == dst:
            break

        # Relax edges
        for neighbor, weight in graph.get(current_node, []):
            if weight < 0:
                raise ValueError(f"Negative edge weight detected: {current_node} -> {neighbor} ({weight})")
            new_dist = current_dist + weight
            if new_dist < distances[neighbor]:
                distances[neighbor] = new_dist
                prev[neighbor] = current_node
                heapq.heappush(heap, (new_dist, neighbor))

    # If destination was never reached
    if distances[dst] == float('inf'):
        return float('inf'), []

    # Reconstruct path from src to dst
    path: List[str] = []
    node = dst
    while node != src:
        path.append(node)
        node = prev[node]
    path.append(src)
    path.reverse()

    return distances[dst], path
