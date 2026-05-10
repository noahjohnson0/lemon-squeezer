Write `bloom.py` exporting a Bloom filter:

```python
class BloomFilter:
    """Probabilistic set membership.
    Constructor: BloomFilter(capacity: int, error_rate: float = 0.01)
      - Compute optimal size m and number of hashes k from (capacity, error_rate)
        using the standard formulas: m = -(n*ln(p)) / (ln(2)^2), k = (m/n)*ln(2).
    Methods:
      add(item) -> None       # insert (hashable item, str/bytes/int)
      __contains__(item) -> bool    # membership test
      __len__() -> int        # number of items added (approximate is fine, exact preferred)
    """
```

Constraints:
- Pure stdlib (`hashlib` ok). No third-party (`pybloom_live` etc).
- For non-bytes items, encode via `str(item).encode('utf-8')` consistently for both add and __contains__.
- Items added must always be reported present (no false negatives). False positives are allowed at roughly the configured rate.

Create only `bloom.py`. Don't run it.
