import heapq

def shortest_path(graph: dict[str, list[tuple[str, float]]], src: str, dst: str) -> tuple[float, list[str]]:
    """Compute the shortest path from src to dst in a weighted directed graph.

    graph: {node_id: [(neighbour_id, weight), ...]} — edges have non-negative weights.
    Returns (total_distance, [src, ..., dst]).
    If no path exists, returns (float('inf'), []).
    If src == dst, returns (0.0, [src])."""
    
    if src == dst:
        return (0.0, [src])
    
    # Initialize distances to all nodes as infinity, except the source
    distances = {node: float('inf') for node in graph}
    distances[src] = 0.0
    
    # Priority queue: (distance, current node, path)
    priority_queue = [(0.0, src, [src])]
    
    while priority_queue:
        current_dist, current_node, path = heapq.heappop(priority_queue)
        
        # If we've reached the destination, return the result
        if current_node == dst:
            return (current_dist, path)
        
        # Skip if a shorter path to this node has already been found
        if current_dist > distances[current_node]:
            continue
        
        # Explore all neighbors
        for neighbor, weight in graph.get(current_node, []):
            new_dist = current_dist + weight
            if new_dist < distances[neighbor]:
                distances[neighbor] = new_dist
                heapq.heappush(priority_queue, (new_dist, neighbor, path + [neighbor]))
    
    # If no path was found
    return (float('inf'), [])
