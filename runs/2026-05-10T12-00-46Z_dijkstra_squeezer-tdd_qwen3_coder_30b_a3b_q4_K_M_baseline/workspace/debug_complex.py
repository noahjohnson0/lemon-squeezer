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
    
    print(f"Starting from {src} to {dst}")
    print(f"Graph: {graph}")
    
    # Dijkstra's algorithm
    while pq:
        current_distance, current_node = heapq.heappop(pq)
        print(f"Visiting {current_node} with distance {current_distance}")
        
        # Skip if already visited
        if current_node in visited:
            continue
            
        visited.add(current_node)
        
        # Early termination if we reached the destination
        if current_node == dst:
            print(f"Reached destination {dst}")
            break
            
        # Explore neighbors
        neighbors = graph.get(current_node, [])
        print(f"Neighbors of {current_node}: {neighbors}")
        for neighbor, weight in neighbors:
            if neighbor not in visited:
                new_distance = current_distance + weight
                print(f"  Edge {current_node} -> {neighbor} with weight {weight}, new_distance = {new_distance}")
                
                # If we found a shorter path, update it
                if new_distance < distances[neighbor]:
                    distances[neighbor] = new_distance
                    previous[neighbor] = current_node
                    heapq.heappush(pq, (new_distance, neighbor))
                    print(f"    Updated distance to {neighbor}: {new_distance}, added to queue")
    
    print(f"Final distances: {dict(distances)}")
    print(f"Previous nodes: {previous}")
    
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
    
    print(f"Path reconstructed: {path}")
    
    # Return distance and path
    return distances[dst], path

# Test with the complex case that failed
graph = {
    'A': [('B', 3.0), ('C', 2.0)],
    'B': [('D', 4.0)],
    'C': [('D', 5.0)],
    'D': []
}

distance, path = shortest_path(graph, 'A', 'D')
print(f"Result: distance = {distance}, path = {path}")
print(f"Expected distance = 10.0")