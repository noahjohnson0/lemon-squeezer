Write `scanner.py` - a small TCP port scanner suitable for inventorying services on your own network. Educational/defensive use only.

Required interface:

```python
def scan(host: str, ports: list[int], timeout: float = 0.5) -> dict[int, str]:
    """
    Try a TCP connect to each port on host. Return a dict {port: state} where
    state is one of:
      "open"     - connect succeeded
      "closed"   - connection actively refused (RST)
      "filtered" - timeout / host unreachable / other socket error
    """
```

Requirements:
1. Use the standard `socket` module (no third-party deps).
2. Use `socket.AF_INET` + `socket.SOCK_STREAM` and `connect_ex` (or `connect` with try/except).
3. Distinguish refused (`ConnectionRefusedError`) from timeout (`socket.timeout`) - they map to `"closed"` vs `"filtered"`.
4. Close every socket you open.
5. The function MUST work with at least 100 ports without leaking sockets (use a context manager or explicit close in a finally).
6. Provide a CLI: `python3 scanner.py <host> <port_a>[,<port_b>,...]` prints `<port> <state>` lines, sorted by port.

Create only `scanner.py`. Don't run it.
