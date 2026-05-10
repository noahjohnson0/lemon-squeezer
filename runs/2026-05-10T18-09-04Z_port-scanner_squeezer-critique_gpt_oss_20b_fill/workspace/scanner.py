#!/usr/bin/env python3
"""Simple TCP port scanner.

This module provides a single function ``scan`` that attempts to establish a TCP
connection to a list of ports on a host. The function returns a mapping of
``port -> state`` where the state can be one of ``"open"``, ``"closed"`` or
``"filtered"``.

A small command‑line interface is also included: ``python3 scanner.py
<host> <port_a>,<port_b>,...`` will print the results sorted by port number.

The scanner is intentionally very small and uses only the standard library –
no external dependencies.
"""

from __future__ import annotations

import sys
import errno
import socket
from typing import Dict, List


def scan(host: str, ports: List[int], timeout: float = 0.5) -> Dict[int, str]:
    """Try a TCP connect to each port on *host*.

    Parameters
    ----------
    host:
        The target hostname or IPv4 address.
    ports:
        A list of TCP port numbers to scan.
    timeout:
        Maximum time to wait for a TCP connection attempt.

    Returns
    -------
    Dict[int, str]
        Mapping from port to one of ``"open"``, ``"closed"`` or ``"filtered"``.

    Notes
    -----
    * ``"open"``   – the ``connect`` succeeded.
    * ``"closed"`` – the host actively refused the connection (RST).
    * ``"filtered"`` – a timeout, host unreachable, or any other socket error.
    """
    result: Dict[int, str] = {}
    for port in ports:
        # Use a context‑manager socket to ensure it always gets closed.
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(timeout)
            try:
                err = sock.connect_ex((host, port))
            except socket.error as exc:  # pragma: no cover - unlikely path
                # If an exception occurs that connect_ex did not capture we
                # treat it as filtered.
                err = exc.errno or errno.ENETUNREACH
            if err == 0:
                state = "open"
            elif err == errno.ECONNREFUSED:
                state = "closed"
            else:
                # For timeout we get ETIMEDOUT; any other error is considered
                # filtered for the purposes of this simple scanner.
                state = "filtered"
            result[port] = state
    return result


def _parse_ports(port_str: str) -> List[int]:
    """Parse a comma‑separated list of ports into integers.

    ``port_range`` may contain a single integer, e.g. ``"80"`` or a comma
    separated list, e.g. ``"22,80,443"``. Whitespace is ignored.
    """
    ports = []
    for part in port_str.split(","):
        part = part.strip()
        if not part:
            continue
        try:
            value = int(part)
        except ValueError as exc:  # pragma: no cover - defensive
            raise ValueError(f"Invalid port value: {part!r}") from exc
        if not (0 <= value <= 65535):  # pragma: no cover - defensive
            raise ValueError(f"Port out of range (0–65535): {value}")
        ports.append(value)
    return ports


def _main(argv: List[str]) -> None:
    if len(argv) != 3:
        print("Usage: python3 scanner.py <host> <port_a>[,<port_b>,...]", file=sys.stderr)
        sys.exit(1)

    host = argv[1]
    ports = _parse_ports(argv[2])
    results = scan(host, ports)
    for port in sorted(results):
        print(f"{port} {results[port]}")


if __name__ == "__main__":  # pragma: no cover
    _main(sys.argv)
