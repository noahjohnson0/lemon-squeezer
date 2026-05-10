#!/usr/bin/env python3
"""
A small TCP port scanner suitable for inventorying services on your own network.
Educational/defensive use only.

Usage:
    python3 scanner.py <host> <port1,port2,...>

The script will attempt to connect to each specified port on the given host
and print the result for each port in ascending order.

The core functionality is provided by the `scan` function, which can be
imported and used programmatically.
"""

import socket
import sys
from typing import Dict, List


def scan(host: str, ports: List[int], timeout: float = 0.5) -> Dict[int, str]:
    """
    Try a TCP connect to each port on host. Return a dict {port: state} where
    state is one of:
      "open"     — connect succeeded
      "closed"   — connection actively refused (RST)
      "filtered" — timeout / host unreachable / other socket error
    """
    results: Dict[int, str] = {}

    for port in ports:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(timeout)
        try:
            s.connect((host, port))
            results[port] = "open"
        except ConnectionRefusedError:
            results[port] = "closed"
        except (socket.timeout, OSError):
            results[port] = "filtered"
        finally:
            s.close()

    return results


def _parse_ports(port_str: str) -> List[int]:
    """Parse a comma-separated list of ports into a list of integers."""
    try:
        return [int(p.strip()) for p in port_str.split(",") if p.strip()]
    except ValueError as exc:
        raise ValueError("Ports must be integers separated by commas.") from exc


def _main(argv: List[str]) -> None:
    if len(argv) != 3:
        print(f"Usage: {argv[0]} <host> <port1,port2,...>")
        sys.exit(1)

    host = argv[1]
    try:
        ports = _parse_ports(argv[2])
    except ValueError as exc:
        print(exc)
        sys.exit(1)

    results = scan(host, ports)

    for port in sorted(results):
        print(f"{port} {results[port]}")


if __name__ == "__main__":
    _main(sys.argv)
