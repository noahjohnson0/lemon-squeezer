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
        # Move to end (mark as recently used)
        self.cache.move_to_end(key)
        return self.cache[key]
    
    def put(self, key, value) -> None:
        if key in self.cache:
            # Update existing key and move to end
            self.cache.move_to_end(key)
        elif len(self.cache) >= self.capacity:
            # Remove least recently used (first item)
            self.cache.popitem(last=False)
        self.cache[key] = value
    
    def __len__(self) -> int:
        return len(self.cache)
    
    def __contains__(self, key) -> bool:
        return key in self.cache
