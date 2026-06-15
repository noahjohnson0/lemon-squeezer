Write `limiter.py` exporting a PRECISE sliding-window rate limiter:

```python
class RateLimiter:
    """Precise sliding-window rate limiter.

    max_events:     maximum number of events permitted within ANY window of
                    length `window_seconds` (a hard cap on a moving window,
                    NOT a fixed/tumbling window).
    window_seconds: width of the sliding window, in seconds.

    Time is PASSED IN via the `now` argument to allow(); the limiter must
    NEVER read the real clock (no time.time(), no datetime.now()).
    """
    def __init__(self, max_events: int, window_seconds: float): ...

    def allow(self, key, now) -> bool:
        """Record-and-decide for `key` at timestamp `now` (seconds, float).

        Returns True and COUNTS the event iff, after dropping events strictly
        older than the window, the number of events for `key` in the half-open
        interval (now - window_seconds, now] would be <= max_events.
        Returns False and does NOT count the event otherwise.
        """
```

## Exact semantics the rubric checks

- **Sliding, not fixed.** An event at time `t` still occupies the window for
  every query time in `(t, t + window_seconds]`. It is dropped (no longer
  counted) once `now - t >= window_seconds` (i.e. the window is the half-open
  interval `(now - window_seconds, now]`). This means you must NOT allow a 2x
  burst straddling a window boundary: with `max_events=5, window=10`, five
  events at t=0 and five at t=9.999 within the same 10s span must be limited;
  a fixed-window limiter wrongly permits all ten.
- **Boundary is exact.** An event whose age is exactly `window_seconds` is OUT
  of the window (dropped); an event still strictly inside is counted.
- **Denied events do not count.** A rejected `allow` must NOT be recorded, so
  it cannot push out a later legitimate event or occupy a window slot.
- **Per-key isolation.** Each `key` has an independent window; one key hitting
  its limit must not affect another key. Keys may be any hashable.
- **Equal timestamps.** Multiple events at the SAME `now` each consume a slot
  (the (n+1)-th identical-timestamp event is denied once the cap is reached).
- **Monotonic non-decreasing `now`.** Callers pass `now` non-decreasing per
  key; you may assume that for correctness, but must still evict correctly.
- **Bounded memory / eviction.** Per key you retain at most `max_events`
  in-window timestamps; events that have aged out are evicted, so memory does
  NOT grow without bound under a long stream of calls. A key's stored
  timestamp count must never exceed `max_events` after an `allow` returns.
- **Validation.** `max_events` must be an int >= 1 and `window_seconds` a
  number > 0; otherwise raise `ValueError` in `__init__`.
- **Performance.** `allow` must be amortized O(1) (or O(log n)) per call, not
  O(n) over all history. A stream of ~200k calls must complete in a couple of
  seconds. A quadratic implementation that rescans full per-key history every
  call will time out.

Create only `limiter.py`. Do not read the real clock. Don't run it.
