import heapq

def shortest_path(
    graph: dict[str, list[tuple[str, float]]],
    src: str,
    dst: str
) -> tuple[float, list[str]]:
    if src == dst:
        return (0.0, [src])
    
    if not graph or src not in graph or dst not in graph:
        return (float('inf'), [])

    dist = {node: float('inf') for node in graph}
    prev = {node: None for node in graph}
    dist[src] = 0.0
    
    heap = [(0.0, src)]
    
    while heap:
        d, u = heapq.heappop(heap)
        
        if d > dist[u]:
            continue
        
        for v, w in graph[u]:
            new_d = d + w
            if new_d < dist[v]:
                dist[v] = new_d
                prev[v] = u
                heapq.heappush(heap, (new_d, v))

    if dist[dst] == float('inf'):
        return (float('inf'), [])

    # Reconstruct path
    path = []
    node = dst
    while node is not None:
        path.append(node)
        node = prev[node]
    path.reverse()
    
    return (dist[dst], path)