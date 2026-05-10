from collections import OrderedDict

class LRUCache:
    def __init__(self, capacity: int):
        if capacity <= 0:
            raise ValueError("Capacity must be positive")
        self.capacity = capacity
        self._cache = OrderedDict()

    def get(self, key):
        if key in self._cache:
            value = self._cache[key]
            self._cache.move_to_end(key)
            return value
        return None

    def put(self, key, value):
        if key in self._cache:
            self._cache[key] = value
            self._cache.move_to_end(key)
        else:
            if len(self._cache) >= self.capacity:
                self._cache.popitem(last=False)
            self._cache[key] = value

    def __len__(self):
        return len(self._cache)

    def __contains__(self, key):
        return key in self._cache
