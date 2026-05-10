Write `ratelimit.py` exporting a token-bucket rate limiter:

```python
class TokenBucket:
    """Token-bucket rate limiter.

    capacity: maximum tokens the bucket can hold (also the burst size)
    refill_rate: tokens added per second (steady-state allowance)
    now_fn: callable returning current time in seconds (for testability; default time.time)

    The bucket starts FULL (capacity tokens). Each allow(cost=1) consumes `cost`
    tokens if available and returns True; otherwise returns False (no partial consume).
    Refill happens lazily: each call computes elapsed time since last refill
    and adds elapsed * refill_rate tokens, capped at capacity.
    """
    def __init__(self, capacity: float, refill_rate: float, now_fn=None): ...
    def allow(self, cost: float = 1.0) -> bool: ...
    def tokens(self) -> float: ...  # current token count (after lazy refill)
```

- Capacity and refill_rate must be > 0; raise ValueError otherwise.
- Tokens never exceed capacity even after long idle periods.

Create only `ratelimit.py`. Don't run it.
