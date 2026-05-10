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
    result = {}
    for port in ports:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        try:
            err = sock.connect_ex((host, port))
            if err == 0:
                result[port] = "open"
            else:
                if err == socket.errno.ECONNREFUSED:
                    result[port] = "closed"
                else:
                    result[port] = "filtered"
        finally:
            sock.close()
    return result

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 scanner.py <host> <port_a>[,<port_b>,...]")
        sys.exit(1)
    host = sys.argv[1]
    ports_str = sys.argv[2]
    try:
        ports = list(map(int, ports_str.split(',')))
    except ValueError:
        print("Error: Ports must be integers separated by commas.")
        sys.exit(1)
    results = scan(host, ports)
    for port in sorted(results.keys()):
        print(f"{port} {results[port]}")
