import heapq
from typing import Dict, List, Tuple

def shortest_path(graph: Dict[str, List[Tuple[str, float]]], src: str, dst: str) -> Tuple[float, List[str]]:
    """Compute the shortest path from src to dst in a weighted directed graph.

    graph: {node_id: [(neighbour_id, weight), ...]} — edges have non-negative weights.
    Returns (total_distance, [src, ..., dst]).
    If no path exists, returns (float('inf'), []).
    If src == dst, returns (0.0, [src])."""
    
    # Initialize distances and previous nodes
    distances = {node: float('inf') for node in graph}
    distances[src] = 0.0
    previous = {}
    
    # Priority queue: (distance, node)
    pq = [(0.0, src)]
    visited = set()
    
    while pq:
        current_distance, current_node = heapq.heappop(pq)
        
        # Skip if already visited
        if current_node in visited:
            continue
            
        visited.add(current_node)
        
        # If we reached the destination
        if current_node == dst:
            break
            
        # Explore neighbors
        for neighbor, weight in graph.get(current_node, []):
            if neighbor not in visited:
                new_distance = current_distance + weight
                
                # If we found a shorter path
                if new_distance < distances[neighbor]:
                    distances[neighbor] = new_distance
                    previous[neighbor] = current_node
                    heapq.heappush(pq, (new_distance, neighbor))
    
    # Reconstruct path
    if distances[dst] == float('inf'):
        return (float('inf'), [])
    
    path = []
    current = dst
    while current in previous:
        path.append(current)
        current = previous[current]
    path.append(src)
    path.reverse()
    
    return (distances[dst], path)
