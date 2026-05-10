"""
A simple Least‑Recently‑Used cache implementation.

The cache stores up to ``capacity`` key/value pairs.  When a key is accessed via
``get`` or updated via ``put`` it is considered *recently used* and the
oldest entry is evicted when the cache grows beyond its capacity.

The implementation relies on :class:`collections.OrderedDict` which keeps
elements in insertion order (and provides efficient ``move_to_end``
operations).  All required operations run in O(1) amortised time.

Example
-------
>>> cache = LRUCache(2)
>>> cache.put("a", 1)
>>> cache.put("b", 2)
>>> cache.get("a")
1
>>> cache.put("c", 3)
>>> "b" in cache
False
>>> len(cache)
2
"""

from __future__ import annotations

from collections import OrderedDict
from typing import Any

__all__ = ["LRUCache"]


class LRUCache:
    """An O(1) amortised least‑recently‑used cache.

    Parameters
    ----------
    capacity:
        Maximum number of items the cache may hold.  Must be a positive
        integer; otherwise :class:`ValueError` is raised.
    """

    def __init__(self, capacity: int) -> None:
        if not isinstance(capacity, int):
            raise TypeError("capacity must be an integer")
        if capacity <= 0:
            raise ValueError("capacity must be a positive integer")

        self._capacity: int = capacity
        self._data: OrderedDict[Any, Any] = OrderedDict()

    # ---------- container protocol methods ----------
    def __len__(self) -> int:  # pragma: no cover - trivial
        return len(self._data)

    def __contains__(self, key: Any) -> bool:  # pragma: no cover - trivial
        return key in self._data

    # ---------- public API ----------
    def get(self, key: Any) -> Any | None:
        """Return the value associated with *key*.

        If *key* is present its entry is moved to the end of the internal
        :class:`OrderedDict` to indicate recent use.  ``None`` is returned if
        the key is missing.
        """

        try:
            value = self._data.pop(key)
        except KeyError:
            return None
        # Re‑insert to mark as recently used
        self._data[key] = value
        return value

    def put(self, key: Any, value: Any) -> None:
        """Insert or update *key* → *value*.

        If the key already exists its value is updated and the entry is
        moved to the end of the order.  When adding a new key the cache may
        exceed its capacity and in that case the least‑recently‑used entry
        (the first item in the :class:`OrderedDict`) is discarded.
        """

        if key in self._data:
            # Existing key: remove first so that re‑insertion moves it to the end
            self._data.pop(key)
        elif len(self._data) >= self._capacity:
            # Evict the least recently used item (the first one)
            self._data.popitem(last=False)

        self._data[key] = value

    # ---------- representation (debugging helper) ----------
    def __repr__(self) -> str:  # pragma: no cover - debugging helper
        items = ", ".join(f"{k!r}: {v!r}" for k, v in self._data.items())
        return f"{self.__class__.__name__}(capacity={self._capacity}, {{ {items} }})"

# only LRUCache is exported

