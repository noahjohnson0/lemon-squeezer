import heapq

def shortest_path(graph: dict[str, list[tuple[str, float]]], src: str, dst: str) -> tuple[float, list[str]]:
    """Compute the shortest path from src to dst in a weighted directed graph.

    graph: {node_id: [(neighbour_id, weight), ...]} — edges have non-negative weights.
    Returns (total_distance, [src, ..., dst]).
    If no path exists, returns (float('inf'), []).
    If src == dst, returns (0.0, [src])."""
    
    # Initialize distances and previous nodes
    distances = {node: float('inf') for node in graph}
    previous_nodes = {node: None for node in graph}

    # Set initial distance to 0
    distances[src] = 0

    # Create priority queue with source node
    pq = [(0, src)]

    while pq:
        current_distance, current_node = heapq.heappop(pq)

        if current_distance > distances[current_node]:
            continue

        for neighbour_id, weight in graph[current_node]:
            distance = current_distance + weight

            if distance < distances[neighbour_id]:
                distances[neighbour_id] = distance
                previous_nodes[neighbour_id] = current_node
                heapq.heappush(pq, (distance, neighbour_id))

    # Build path from source to destination
    path = []
    current_node = dst

    while current_node is not None:
        path.append(current_node)
        current_node = previous_nodes[current_node]

    path.reverse()

    return distances[dst], path if dst in graph else []
