import socket
import sys

def scan(host: str, ports: list[int], timeout: float = 0.5) -> dict[int, str]:
    """
    Try a TCP connect to each port on host. Return a dict {port: state} where
    state is one of:
      "open"     — connect succeeded
      "closed"   — connection actively refused (RST)
      "filtered" — timeout / host unreachable / other socket error
    """
    results = {}
    for port in ports:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        try:
            result = sock.connect_ex((host, port))
            if result == 0:
                state = "open"
            else:
                state = "closed" if result == 111 else "filtered"
        except (socket.timeout, ConnectionRefusedError):
            state = "closed"
        except Exception as e:
            state = "filtered"
        finally:
            sock.close()
            results[port] = state
    return results

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python3 scanner.py <host> <port_a>[,<port_b>,...]")
        sys.exit(1)

    host = sys.argv[1]
    ports = [int(port) for port in sys.argv[2].split(',')]
    results = scan(host, ports)
    
    for port, state in sorted(results.items()):
        print(f"{port} {state}")
