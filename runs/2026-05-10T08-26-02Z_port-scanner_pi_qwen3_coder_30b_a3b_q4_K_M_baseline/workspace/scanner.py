#!/usr/bin/env python3
import socket
import sys
from typing import List, Dict


def scan(host: str, ports: List[int], timeout: float = 0.5) -> Dict[int, str]:
    """
    Try a TCP connect to each port on host. Return a dict {port: state} where
    state is one of:
      "open"     — connect succeeded
      "closed"   — connection actively refused (RST)
      "filtered" — timeout / host unreachable / other socket error
    """
    result = {}
    
    for port in ports:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        
        try:
            sock.connect((host, port))
            result[port] = "open"
        except ConnectionRefusedError:
            result[port] = "closed"
        except socket.timeout:
            result[port] = "filtered"
        except Exception:
            result[port] = "filtered"
        finally:
            sock.close()
    
    return result


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <host> <port_a>[,<port_b>,...]")
        sys.exit(1)
    
    host = sys.argv[1]
    ports_str = sys.argv[2]
    ports = [int(p) for p in ports_str.split(",")]
    
    results = scan(host, ports)
    
    # Sort by port number and print results
    for port in sorted(results.keys()):
        print(f"{port} {results[port]}")


if __name__ == "__main__":
    main()