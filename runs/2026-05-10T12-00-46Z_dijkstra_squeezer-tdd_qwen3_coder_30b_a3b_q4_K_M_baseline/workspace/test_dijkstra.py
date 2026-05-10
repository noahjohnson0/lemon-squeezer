import pytest
from dijkstra import shortest_path

def test_simple_path():
    """Test a simple path between two nodes."""
    graph = {
        'A': [('B', 1.0)],
        'B': [('C', 2.0)],
        'C': []
    }
    distance, path = shortest_path(graph, 'A', 'C')
    assert distance == 3.0
    assert path == ['A', 'B', 'C']

def test_multiple_paths():
    """Test with multiple possible paths - should choose the shortest."""
    graph = {
        'A': [('B', 3.0), ('C', 2.0)],
        'B': [('D', 1.0)],
        'C': [('D', 4.0)],
        'D': []
    }
    distance, path = shortest_path(graph, 'A', 'D')
    assert distance == 4.0  # A->C->D = 2 + 4 = 6, A->B->D = 3 + 1 = 4
    assert path == ['A', 'B', 'D']

def test_same_source_destination():
    """Test when source and destination are the same."""
    graph = {
        'A': [('B', 1.0)],
        'B': [('A', 1.0)]
    }
    distance, path = shortest_path(graph, 'A', 'A')
    assert distance == 0.0
    assert path == ['A']

def test_no_path_exists():
    """Test when no path exists between source and destination."""
    graph = {
        'A': [('B', 1.0)],
        'B': [],
        'C': [('D', 1.0)],
        'D': []
    }
    distance, path = shortest_path(graph, 'A', 'D')
    assert distance == float('inf')
    assert path == []

def test_empty_graph():
    """Test with empty graph."""
    graph = {}
    distance, path = shortest_path(graph, 'A', 'B')
    assert distance == float('inf')
    assert path == []

def test_single_node():
    """Test with a single node."""
    graph = {
        'A': []
    }
    distance, path = shortest_path(graph, 'A', 'A')
    assert distance == 0.0
    assert path == ['A']

def test_complex_graph():
    """Test a more complex graph with multiple paths."""
    graph = {
        'A': [('B', 4.0), ('C', 2.0)],
        'B': [('C', 1.0), ('D', 5.0)],
        'C': [('D', 8.0), ('E', 10.0)],
        'D': [('E', 2.0)],
        'E': []
    }
    distance, path = shortest_path(graph, 'A', 'E')
    # Shortest path: A->C->B->D->E = 2 + 1 + 5 + 2 = 10
    assert distance == 10.0
    assert path == ['A', 'C', 'B', 'D', 'E']

def test_graph_with_negative_weights():
    """Test that algorithm handles negative weights (should work for non-negative)."""
    graph = {
        'A': [('B', 1.0)],
        'B': [('C', -2.0)],
        'C': []
    }
    # This should still work, but the result might be different than expected
    # since we're not implementing Bellman-Ford or similar
    distance, path = shortest_path(graph, 'A', 'C')
    assert distance == -1.0
    assert path == ['A', 'B', 'C']

def test_path_reconstruction():
    """Test that path reconstruction works correctly."""
    graph = {
        'A': [('B', 1.0), ('C', 4.0)],
        'B': [('C', 2.0), ('D', 6.0)],
        'C': [('D', 3.0)],
        'D': []
    }
    distance, path = shortest_path(graph, 'A', 'D')
    assert distance == 6.0  # A->B->C->D = 1 + 2 + 3 = 6
    assert path == ['A', 'B', 'C', 'D']