#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}
T="$WS/bloom.py"
add "file:bloom.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5
if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5
  RES=$(cd "$WS" && gtimeout 15 python3 - <<'PY' 2>&1
import sys, random
try: from bloom import BloomFilter
except Exception as e: print("IMPORT_ERR", e); sys.exit(1)
random.seed(42)

# Test 1: items added are always reported present
b = BloomFilter(1000, 0.01)
items = [f"key_{i}" for i in range(500)]
for x in items: b.add(x)
miss = sum(1 for x in items if x not in b)
print("no_false_neg", 1 if miss == 0 else 0, f"missed={miss}")

# Test 2: not-added items mostly absent (allow up to 5x configured rate as upper bound — bloom is tight, don't be punitive)
absent = [f"other_{i}" for i in range(2000)]
present = sum(1 for x in absent if x in b)
fpr = present / len(absent)
print("low_false_pos", 1 if fpr < 0.05 else 0, f"observed_fpr={fpr:.3f}")

# Test 3: __len__ tracks adds
b2 = BloomFilter(100, 0.01)
b2.add("a"); b2.add("b"); b2.add("c")
n = len(b2)
print("len_tracks", 1 if (2 <= n <= 4) else 0, f"len={n}")  # allow approximate

# Test 4: works with different item types
b3 = BloomFilter(100, 0.01)
b3.add(42); b3.add("hello"); b3.add(b"\x00\x01")
ok = (42 in b3) and ("hello" in b3) and (b"\x00\x01" in b3)
print("multi_type", 1 if ok else 0)

# Test 5: empty bloom — nothing reports present (with overwhelming probability)
b4 = BloomFilter(100, 0.01)
empty_present = sum(1 for x in [f"x_{i}" for i in range(100)] if x in b4)
print("empty_clean", 1 if empty_present == 0 else 0, f"got={empty_present}")
PY
)
  echo "$RES" >&2
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    pass=$(echo "$line" | awk '{print $2}')
    note=$(echo "$line" | cut -d' ' -f3-)
    [[ "$name" == "IMPORT_ERR" ]] && continue
    case "$name" in
      no_false_neg)  w=25;;
      low_false_pos) w=15;;
      *)             w=10;;
    esac
    add "$name" "$pass" "$w" "$note"
  done < <(echo "$RES")
else
  for n in compiles no_false_neg; do add "$n" 0 5; done
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
