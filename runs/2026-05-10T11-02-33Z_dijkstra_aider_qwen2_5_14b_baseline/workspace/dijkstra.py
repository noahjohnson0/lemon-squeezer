import heapq

def shortest_path(graph: dict[str, list[tuple[str, float]]], src: str, dst: str) -> tuple[float, list[str]]:
    """Compute the shortest path from src to dst in a weighted directed graph.

    graph: {node_id: [(neighbour_id, weight), ...]} — edges have non-negative weights.
    Returns (total_distance, [src, ..., dst]).
    If no path exists, returns (float('inf'), []).
    If src == dst, returns (0.0, [src]).

    Implementation uses Dijkstra's algorithm with a priority queue (heapq).
    """
    
    if src == dst:
        return 0.0, [src]

    # Initialize distances and previous nodes
    distances = {node: float('inf') for node in graph}
    distances[src] = 0

    # Priority queue to store the current distance and node
    priority_queue = [(0, src)]
    
    while priority_queue:
        current_distance, current_node = heapq.heappop(priority_queue)
        
        if current_node == dst:
            path = []
            previous_nodes = {}  # Initialize this dictionary here
            while current_node != src:
                path.append(current_node)
                current_node = previous_nodes[current_node]
            path.append(src)
            return distances[dst], path[::-1]

        for neighbor, weight in graph.get(current_node, []):
            distance = current_distance + weight
            if distance < distances[neighbor]:
                distances[neighbor] = distance
                heapq.heappush(priority_queue, (distance, neighbor))
                previous_nodes[neighbor] = current_node  # Use the initialized dictionary

    return float('inf'), []

# Example usage:
# graph = {
#     'A': [('B', 1), ('C', 4)],
#     'B': [('C', 1), ('D', 2)],
#     'C': [('D', 1)],
#     'D': []
# }
# print(shortest_path(graph, 'A', 'D'))
