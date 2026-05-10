from collections import OrderedDict
from typing import Any, Dict

class LRUCache:
    """
    A simple Least-Recently-Used (LRU) cache implementation.

    Parameters
    ----------
    capacity : int
        Maximum number of items the cache can hold. Must be a positive integer.
    """

    def __init__(self, capacity: int):
        if not isinstance(capacity, int) or capacity <= 0:
            raise ValueError("capacity must be a positive integer")
        self._capacity: int = capacity
        self._cache: OrderedDict[Any, Any] = OrderedDict()

    def get(self, key: Any) -> Any | None:
        """
        Retrieve the value associated with `key` if present, marking it as recently used.

        Parameters
        ----------
        key : Any
            The key to look up.

        Returns
        -------
        Any | None
            The value if the key exists, otherwise None.
        """
        if key not in self._cache:
            return None
        # Move key to the end to mark it as recently used
        value = self._cache.pop(key)
        self._cache[key] = value
        return value

    def put(self, key: Any, value: Any) -> None:
        """
        Insert or update the value for `key`. If the cache exceeds its capacity,
        evict the least-recently-used item.

        Parameters
        ----------
        key : Any
            The key to insert or update.
        value : Any
            The value to associate with the key.
        """
        if key in self._cache:
            # Update existing key and mark as recently used
            self._cache.pop(key)
        self._cache[key] = value
        if len(self._cache) > self._capacity:
            # Evict the least-recently-used item (first item in OrderedDict)
            self._cache.popitem(last=False)

    def __len__(self) -> int:
        """Return the current number of items stored in the cache."""
        return len(self._cache)

    def __contains__(self, key: Any) -> bool:
        """Check if `key` is present in the cache without affecting recency."""
        return key in self._cache
