import heapq
from collections import defaultdict

def shortest_path(graph, src, dst):
    """
    Find the shortest path in a weighted directed graph using Dijkstra's algorithm.
    
    Args:
        graph: dict mapping nodes to list of (neighbor, weight) tuples
        src: source node
        dst: destination node
    
    Returns:
        tuple: (distance, path) where distance is the shortest distance and
               path is the list of nodes forming the shortest path
    """
    # Initialize distances and previous nodes for path reconstruction
    distances = defaultdict(lambda: float('inf'))
    previous = {}
    
    # Distance to source is 0
    distances[src] = 0
    
    # Priority queue: (distance, node)
    pq = [(0, src)]
    visited = set()
    
    # Dijkstra's algorithm
    while pq:
        current_distance, current_node = heapq.heappop(pq)
        
        # Skip if already visited
        if current_node in visited:
            continue
            
        visited.add(current_node)
        
        # Early termination if we reached the destination
        if current_node == dst:
            break
            
        # Explore neighbors
        neighbors = graph.get(current_node, [])
        for neighbor, weight in neighbors:
            if neighbor not in visited:
                new_distance = current_distance + weight
                
                # If we found a shorter path, update it
                if new_distance < distances[neighbor]:
                    distances[neighbor] = new_distance
                    previous[neighbor] = current_node
                    heapq.heappush(pq, (new_distance, neighbor))
    
    # Reconstruct path - build it from dst back to src
    path = []
    current = dst
    if distances[dst] == float('inf'):
        # No path exists, return empty path
        return float('inf'), []
    elif current in previous or current == src:
        # If destination is reachable, build the path
        while current in previous:
            path.append(current)
            current = previous[current]
        path.append(src)
        path.reverse()
    
    # Return distance and path
    return distances[dst], path