Write `lru_cache.py` exporting a class `LRUCache(capacity: int)` implementing a Least-Recently-Used cache.

Required methods:
- `get(key) -> Any | None` — returns value if present (and marks as recently used); returns `None` if absent.
- `put(key, value) -> None` — inserts/updates; evicts the least-recently-used key if `len(self) > capacity`.
- `__len__()` returns current number of items.
- `__contains__(key)` checks membership without affecting recency.

Constraints:
- O(1) amortised for both `get` and `put`. (Use a `dict` + a doubly-linked list, OR Python's `OrderedDict`.)
- Capacity 0 means it never stores anything; capacity must be a positive int (raise `ValueError` if 0 or negative).
- Updating an existing key with `put` must mark it as recently used.

Create only `lru_cache.py`. Don't run it.
