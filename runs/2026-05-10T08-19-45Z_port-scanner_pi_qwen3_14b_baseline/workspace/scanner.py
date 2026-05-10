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
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(timeout)
            try:
                sock.connect((host, port))
                results[port] = "open"
            except socket.timeout:
                results[port] = "filtered"
            except ConnectionRefusedError:
                results[port] = "closed"
            except Exception:
                results[port] = "filtered"
    return results


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 scanner.py <host> <port1,[port2,...]>")
        sys.exit(1)
    
    host = sys.argv[1]
    ports_str = sys.argv[2]
    
    try:
        ports = list(map(int, ports_str.split(',')))
    except ValueError:
        print("Error: Ports must be integers separated by commas")
        sys.exit(1)

    results = scan(host, ports)
    
    for port in sorted(results):
        print(f"{port} {results[port]}")