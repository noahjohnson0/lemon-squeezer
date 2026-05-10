from collections import OrderedDict
from typing import Any  # Add this line to fix the error

class LRUCache:
    def __init__(self, capacity: int):
        if capacity <= 0:
            raise ValueError("Capacity must be a positive integer")
        self.capacity = capacity
        self.cache = OrderedDict()

    def get(self, key) -> Any | None:
        if key in self.cache:
            value = self.cache.pop(key)
            self.cache[key] = value  # move to end (mark as recently used)
            return value
        else:
            return None

    def put(self, key, value) -> None:
        if len(self.cache) >= self.capacity:
            self.cache.popitem(last=False)  # evict the least-recently-used item
        self.cache[key] = value

    def __len__(self):
        return len(self.cache)

    def __contains__(self, key):
        return key in self.cache
