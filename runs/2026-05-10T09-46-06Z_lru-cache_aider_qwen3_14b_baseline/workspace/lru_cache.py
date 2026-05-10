from collections import OrderedDict

class LRUCache:
    def __init__(self, capacity: int):
        if capacity <= 0:
            raise ValueError("Capacity must be a positive integer")
        self.capacity = capacity
        self.cache = OrderedDict()

    def get(self, key):
        if key in self.cache:
            # Move to end to mark as recently used
            self.cache.move_to_end(key)
            return self.cache[key]
        return None

    def put(self, key, value):
        if key in self.cache:
            # Update value and move to end
            self.cache[key] = value
            self.cache.move_to_end(key)
        else:
            # Add new item
            self.cache[key] = value
            # Check if capacity is exceeded
            if len(self.cache) > self.capacity:
                # Remove least recently used (first item)
                self.cache.popitem(last=False)

    def __len__(self):
        return len(self.cache)

    def __contains__(self, key):
        return key in self.cache
