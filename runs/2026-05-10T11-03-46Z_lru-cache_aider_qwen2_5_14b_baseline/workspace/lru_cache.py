from collections import OrderedDict
from typing import Any

class LRUCache:

    def __init__(self, capacity: int):
        if capacity <= 0:
            raise ValueError("Capacity must be a positive integer")
        
        self.capacity = capacity
        self.cache = OrderedDict()

    def get(self, key) -> Any | None:
        if key not in self.cache:
            return None
        
        # Move accessed item to end of cache (mark as recently used)
        self.cache.move_to_end(key)

        return self.cache[key]

    def put(self, key, value) -> None:
        if key in self.cache:
            # Update existing key and mark it as recently used
            self.cache.move_to_end(key)
        
        elif len(self.cache) >= self.capacity:
            # Evict least-recently-used item (first item in OrderedDict)
            self.cache.popitem(last=False)

        # Insert/update the new item
        self.cache[key] = value

    def __len__(self):
        return len(self.cache)

    def __contains__(self, key) -> bool:
        return key in self.cache


# Example usage (for testing purposes only)
if __name__ == "__main__":
    cache = LRUCache(2)
    cache.put(1, 1)
    cache.put(2, 2)
    print(cache.get(1))       # returns 1
    cache.put(3, 3)           # evicts key 2
    print(cache.get(2))       # returns None
    cache.put(4, 4)           # evicts key 1
    print(cache.get(1))       # returns None
    print(cache.get(3))       # returns 3
    print(cache.get(4))       # returns 4
