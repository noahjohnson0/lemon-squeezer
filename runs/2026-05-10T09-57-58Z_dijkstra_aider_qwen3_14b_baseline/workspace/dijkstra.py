import heapq

def shortest_path(graph: dict[str, list[tuple[str, float]]], src: str, dst: str) -> tuple[float, list[str]]:
    """Compute the shortest path from src to dst in a weighted directed graph.

    graph: {node_id: [(neighbour_id, weight), ...]} — edges have non-negative weights.
    Returns (total_distance, [src, ..., dst]).
    If no path exists, returns (float('inf'), []).
    If src == dst, returns (0.0, [src])."""
    if src == dst:
        return (0.0, [src])
    
    pq = [(0, src)]
    distances = {node: float('inf') for node in graph}
    distances[src] = 0
    previous = {node: None for node in graph}
    
    while pq:
        current_dist, current_node = heapq.heappop(pq)
        
        if current_dist > distances[current_node]:
            continue
        
        if current_node == dst:
            break
        
        for neighbor, weight in graph.get(current_node, []):
            distance = current_dist + weight
            if distance < distances[neighbor]:
                distances[neighbor] = distance
                previous[neighbor] = current_node
                heapq.heappush(pq, (distance, neighbor))
    
    if distances[dst] == float('inf'):
        return (float('inf'), [])
    
    path = []
    current = dst
    while current is not None:
        path.append(current)
        current = previous[current]
    path.reverse()
    
    return (distances[dst], path)
