import heapq

def shortest_path(graph: dict[str, list[tuple[str, float]]], src: str, dst: str) -> tuple[float, list[str]]:
    """Compute the shortest path from src to dst in a weighted directed graph.

    graph: {node_id: [(neighbour_id, weight), ...]} — edges have non-negative weights.
    Returns (total_distance, [src, ..., dst]).
    If no path exists, returns (float('inf'), []).
    If src == dst, returns (0.0, [src]).
    """
    if src == dst:
        return (0.0, [src])
    
    # Initialize distances and previous nodes
    distances = {node: float('inf') for node in graph}
    distances[src] = 0.0
    previous = {node: None for node in graph}
    
    # Priority queue: (distance, node)
    pq = [(0.0, src)]
    
    while pq:
        current_dist, current_node = heapq.heappop(pq)
        
        # Skip if a shorter path to current_node has already been found
        if current_dist > distances[current_node]:
            continue
        
        for neighbor, weight in graph[current_node]:
            new_dist = current_dist + weight
            if new_dist < distances[neighbor]:
                distances[neighbor] = new_dist
                previous[neighbor] = current_node
                heapq.heappush(pq, (new_dist, neighbor))
    
    # Check if destination is unreachable
    if distances[dst] == float('inf'):
        return (float('inf'), [])
    
    # Reconstruct the path from dst to src
    path = []
    current = dst
    while current is not None:
        path.append(current)
        current = previous[current]
    path.reverse()
    
    return (distances[dst], path)
