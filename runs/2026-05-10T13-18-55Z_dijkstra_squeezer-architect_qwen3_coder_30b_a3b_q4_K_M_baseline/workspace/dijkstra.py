import heapq
from typing import Dict, List, Tuple

def shortest_path(graph: Dict[str, List[Tuple[str, float]]], src: str, dst: str) -> Tuple[float, List[str]]:
    """Compute the shortest path from src to dst in a weighted directed graph.

    graph: {node_id: [(neighbour_id, weight), ...]} — edges have non-negative weights.
    Returns (total_distance, [src, ..., dst]).
    If no path exists, returns (float('inf'), []).
    If src == dst, returns (0.0, [src])."""
    
    # Handle special case: src equals dst
    if src == dst:
        return (0.0, [src])
    
    # Check if src or dst is not in the graph
    if src not in graph or dst not in graph:
        return (float('inf'), [])
    
    # Initialize distances and previous nodes
    dist = {node: float('inf') for node in graph}
    prev = {}
    dist[src] = 0.0
    
    # Priority queue: (distance, node_id)
    pq = [(0.0, src)]
    
    while pq:
        current_dist, u = heapq.heappop(pq)
        
        # Skip if we've found a better path already
        if current_dist > dist[u]:
            continue
            
        # Explore neighbors
        for v, weight in graph.get(u, []):
            if dist[u] + weight < dist[v]:
                dist[v] = dist[u] + weight
                prev[v] = u
                heapq.heappush(pq, (dist[v], v))
    
    # Check if dst is reachable
    if dist[dst] == float('inf'):
        return (float('inf'), [])
    
    # Reconstruct path
    path = []
    current = dst
    while current in prev:
        path.append(current)
        current = prev[current]
    path.append(src)
    path.reverse()
    
    return (dist[dst], path)