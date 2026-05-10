#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/ratelimit.py"
add "file:ratelimit.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys
try: from ratelimit import TokenBucket
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)

# Use a manual clock to avoid wall-clock flakiness
clock = [0.0]
def now(): return clock[0]

# Test 1: starts full → first 5 allow(1) succeed, 6th fails
b = TokenBucket(5, 1.0, now_fn=now)
ok = all(b.allow(1) for _ in range(5)) and not b.allow(1)
print("starts_full", 1 if ok else 0)

# Test 2: refill rate works
b2 = TokenBucket(10, 2.0, now_fn=now)
clock[0] = 0.0
for _ in range(10): b2.allow(1)
clock[0] = 5.0  # 5 sec later → 10 tokens refilled, capped at capacity
ok = b2.allow(10) and not b2.allow(1)
print("refill_works", 1 if ok else 0)

# Test 3: capped at capacity
b3 = TokenBucket(3, 1.0, now_fn=now)
clock[0] = 0.0; b3.allow(3)  # drain
clock[0] = 100.0  # very long idle
print("capped_capacity", 1 if abs(b3.tokens() - 3) < 0.001 else 0, b3.tokens())

# Test 4: cost > capacity always fails
b4 = TokenBucket(5, 1.0, now_fn=now)
print("cost_over_capacity", 1 if not b4.allow(10) else 0)

# Test 5: invalid construction
try: TokenBucket(0, 1.0); print("invalid_cap", 0)
except ValueError: print("invalid_cap", 1)
except Exception as e: print("invalid_cap", 0, repr(e))
try: TokenBucket(5, -1.0); print("invalid_rate", 0)
except ValueError: print("invalid_rate", 1)
except Exception as e: print("invalid_rate", 0, repr(e))

# Test 6: failed allow does NOT consume
clock[0] = 0.0
b5 = TokenBucket(2, 1.0, now_fn=now)
b5.allow(2)  # drain
denied = not b5.allow(1)
clock[0] = 0.5  # 0.5 sec → 0.5 tokens
denied2 = not b5.allow(1)
print("failed_no_consume", 1 if (denied and denied2) else 0)
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    add "$name" "$pass" 12 "$note"
  done < <(echo "$RES")
else
  for n in compiles starts_full; do add "$n" 0 5; done
fi
total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in "${checks[@]}"; do
    IFS=$'\t' read -r name pass weight note <<<"$c"
    total=$((total+weight)); [[ "$pass" == "1" ]] && gained=$((gained+weight))
    [[ $first -eq 0 ]] && printf ',\n'
    printf '    {"name":"%s","pass":%s,"weight":%s,"note":"%s"}' "$name" "$pass" "$weight" "$note"
    first=0
  done
  printf '\n  ],\n'
  pct=0; [[ $total -gt 0 ]] && pct=$(( (gained * 100) / total ))
  printf '  "gained": %s,\n  "total": %s,\n  "score_pct": %s\n}\n' "$gained" "$total" "$pct"
}
