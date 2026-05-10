#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/scanner.py"
add "file:scanner.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5

  # Spin up a known-listening socket on a random high port, plus a known-closed port nearby.
  # Then ask scanner to classify them along with a "filtered" port (firewall-style timeout — we use a non-routable IP).
  RES=$(cd "$WS" && gtimeout 20 python3 - <<'PY' 2>&1
import socket, threading, sys, time
try:
    from scanner import scan
except Exception as e:
    print("IMPORT_ERR", e); sys.exit(1)

# 1) start listener on an ephemeral port -> should be "open"
listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
listener.bind(("127.0.0.1", 0))
open_port = listener.getsockname()[1]
listener.listen(8)

# Background accept loop so connect() succeeds
def accept_loop():
    while True:
        try:
            c, _ = listener.accept(); c.close()
        except Exception:
            return
threading.Thread(target=accept_loop, daemon=True).start()

# 2) pick a closed port: any high port that isn't bound. We bind+close to find one then close.
tmp = socket.socket(); tmp.bind(("127.0.0.1", 0)); closed_port = tmp.getsockname()[1]; tmp.close()

ports = [open_port, closed_port]
result = scan("127.0.0.1", ports, timeout=0.5)

print("open_state", result.get(open_port))
print("closed_state", result.get(closed_port))

# 3) filtered: scan a non-routable IP — should hit timeout
result2 = scan("10.255.255.1", [80], timeout=0.5)
print("filtered_state", result2.get(80))

# 4) bulk test (200 ports against localhost, all closed) — checks no socket leak
many = list(range(40000, 40200))
result3 = scan("127.0.0.1", many, timeout=0.2)
print("bulk_count", len(result3))
print("bulk_unique_states", sorted(set(result3.values())))
listener.close()
PY
)
  echo "$RES" >&2
  open_state=$(echo "$RES" | awk '$1=="open_state" {print $2}')
  closed_state=$(echo "$RES" | awk '$1=="closed_state" {print $2}')
  filtered_state=$(echo "$RES" | awk '$1=="filtered_state" {print $2}')
  bulk_count=$(echo "$RES" | awk '$1=="bulk_count" {print $2}')

  [[ "$open_state"     == "open"     ]] && add "detects_open"     1 25 || add "detects_open"     0 25 "got: $open_state"
  [[ "$closed_state"   == "closed"   ]] && add "detects_closed"   1 25 || add "detects_closed"   0 25 "got: $closed_state"
  [[ "$filtered_state" == "filtered" ]] && add "detects_filtered" 1 15 || add "detects_filtered" 0 15 "got: $filtered_state"
  [[ "$bulk_count"     == "200"      ]] && add "bulk_no_leak"     1 15 || add "bulk_no_leak"     0 15 "got: $bulk_count"

  # Static: uses connect_ex or socket.SOCK_STREAM
  grep -qE "connect_ex|SOCK_STREAM" "$T" && add "uses_socket_api" 1 5 || add "uses_socket_api" 0 5
  # Doesn't use third-party
  grep -qE "^\s*import\s+(scapy|nmap|requests)\b" "$T" && add "no_third_party" 0 5 || add "no_third_party" 1 5
else
  for n in compiles detects_open detects_closed detects_filtered bulk_no_leak uses_socket_api no_third_party; do
    add "$n" 0 5
  done
fi

# emit
total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in "${checks[@]}"; do
    IFS=$'\t' read -r name pass weight note <<<"$c"
    total=$((total+weight))
    [[ "$pass" == "1" ]] && gained=$((gained+weight))
    [[ $first -eq 0 ]] && printf ',\n'
    printf '    {"name":"%s","pass":%s,"weight":%s,"note":"%s"}' "$name" "$pass" "$weight" "$note"
    first=0
  done
  printf '\n  ],\n'
  pct=0
  [[ $total -gt 0 ]] && pct=$(( (gained * 100) / total ))
  printf '  "gained": %s,\n  "total": %s,\n  "score_pct": %s\n}\n' "$gained" "$total" "$pct"
}
