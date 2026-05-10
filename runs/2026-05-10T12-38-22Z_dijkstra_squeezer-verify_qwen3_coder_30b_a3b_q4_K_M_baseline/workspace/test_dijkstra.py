import unittest
from dijkstra import shortest_path

class TestShortestPath(unittest.TestCase):
    
    def test_basic_example(self):
        """Test the basic example from the problem"""
        graph = {'A': [('B', 1), ('C', 4)], 'B': [('C', 2), ('D', 5)], 'C': [('D', 1)], 'D': []}
        dist, path = shortest_path(graph, 'A', 'D')
        self.assertEqual(dist, 4)
        self.assertEqual(path, ['A', 'B', 'C', 'D'])
    
    def test_unreachable_nodes(self):
        """Test when there's no path between nodes"""
        graph = {'A': [('B', 1)], 'C': [('D', 1)]}
        dist, path = shortest_path(graph, 'A', 'D')
        self.assertEqual(dist, float('inf'))
        self.assertEqual(path, [])
    
    def test_same_start_end(self):
        """Test when start equals end"""
        graph = {'A': [('B', 1), ('C', 4)], 'B': [('C', 2), ('D', 5)], 'C': [('D', 1)], 'D': []}
        dist, path = shortest_path(graph, 'A', 'A')
        self.assertEqual(dist, 0.0)
        self.assertEqual(path, ['A'])
    
    def test_empty_graph(self):
        """Test with empty graph"""
        graph = {}
        dist, path = shortest_path(graph, 'A', 'B')
        self.assertEqual(dist, float('inf'))
        self.assertEqual(path, [])
    
    def test_single_node(self):
        """Test with single node"""
        graph = {'A': []}
        dist, path = shortest_path(graph, 'A', 'A')
        self.assertEqual(dist, 0.0)
        self.assertEqual(path, ['A'])
    
    def test_property_path_correctness(self):
        """Test that the path actually represents the claimed distance"""
        graph = {'A': [('B', 1), ('C', 4)], 'B': [('C', 2), ('D', 5)], 'C': [('D', 1)], 'D': []}
        
        # For each edge, verify that the path is actually a valid path in the graph
        dist, path = shortest_path(graph, 'A', 'D')
        self.assertEqual(dist, 4)
        self.assertEqual(path, ['A', 'B', 'C', 'D'])
        
        # Verify the path is valid
        for i in range(len(path) - 1):
            current_node = path[i]
            next_node = path[i + 1]
            # Check if next_node is a neighbor of current_node
            neighbors = [n for n, _ in graph.get(current_node, [])]
            self.assertIn(next_node, neighbors)

if __name__ == '__main__':
    unittest.main()