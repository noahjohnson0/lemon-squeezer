import heapq
from typing import Dict, List, Tuple, Union

def shortest_path(graph: Dict[str, List[Tuple[str, int]]], start: str, end: str) -> Tuple[Union[int, float], List[str]]:
    """
    Find the shortest path in a weighted directed graph from start to end node.
    
    Args:
        graph: Dictionary where keys are node names and values are lists of (neighbor, weight) tuples
        start: Starting node name
        end: Target node name
    
    Returns:
        Tuple of (distance, path) where distance is the shortest distance 
        and path is the list of nodes in the shortest path
    """
    # Handle edge cases
    if not graph or start not in graph:
        return float('inf'), []
    
    if start == end:
        return 0.0, [start]
    
    # Dijkstra's algorithm
    distances = {node: float('inf') for node in graph}
    distances[start] = 0
    previous = {}
    visited = set()
    
    # Priority queue: (distance, node)
    pq = [(0, start)]
    
    while pq:
        current_dist, current_node = heapq.heappop(pq)
        
        if current_node in visited:
            continue
            
        visited.add(current_node)
        
        # Check all neighbors
        for neighbor, weight in graph[current_node]:
            if neighbor not in visited:
                new_dist = current_dist + weight
                
                if new_dist < distances[neighbor]:
                    distances[neighbor] = new_dist
                    previous[neighbor] = current_node
                    heapq.heappush(pq, (new_dist, neighbor))
    
    # Reconstruct path if it exists
    if distances[end] == float('inf'):
        return float('inf'), []
    
    # Build path backwards
    path = []
    current = end
    while current in previous:
        path.append(current)
        current = previous[current]
    path.append(start)
    path.reverse()
    
    return distances[end], path

# Test with the exact example from the problem
if __name__ == "__main__":
    # Example from problem description
    example_graph = {
        'A': [('B', 1), ('C', 4)],
        'B': [('C', 2), ('D', 5)],
        'C': [('D', 1)],
        'D': []
    }
    
    distance, path = shortest_path(example_graph, 'A', 'D')
    print(f"Shortest distance from A to D: {distance}")
    print(f"Shortest path from A to D: {path}")
    
    # Test with the actual example input
    result_distance, result_path = shortest_path(example_graph, 'A', 'D')
    assert result_distance == 4
    assert result_path == ['A', 'B', 'C', 'D']
    print("✓ Example test case passed!")