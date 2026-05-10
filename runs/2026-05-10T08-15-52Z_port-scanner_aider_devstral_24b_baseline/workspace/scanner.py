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
                result = sock.connect_ex((host, port))
                if result == 0:
                    results[port] = "open"
                else:
                    results[port] = "closed"
            except ConnectionRefusedError:
                results[port] = "closed"
            except socket.timeout:
                results[port] = "filtered"
            except Exception as e:
                results[port] = "filtered"
    return results

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 scanner.py <host> <port_a>[,<port_b>,...]")
        sys.exit(1)

    host = sys.argv[1]
    ports_str = sys.argv[2]
    try:
        ports = [int(port.strip()) for port in ports_str.split(",")]
    except ValueError:
        print("Ports must be integers.")
        sys.exit(1)

    results = scan(host, ports)
    for port in sorted(results.keys()):
        print(f"{port} {results[port]}")
