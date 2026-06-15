#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  # sanitize: notes go straight into a JSON string via printf %s, so strip
  # backslashes and replace double-quotes (both break the emitted JSON).
  note="${note//\\/ }"
  note="${note//\"/\'}"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/lru_cache.py"

# --- static checks (always emitted) ---
if [[ -f "$T" ]]; then add "file:lru_cache.py" 1 5; else add "file:lru_cache.py" 0 5; fi
if [[ -f "$T" ]] && python3 -m py_compile "$T" 2>/dev/null; then
  add "compiles" 1 5
else
  add "compiles" 0 5
fi

# --- behavioral checks ---
# The python block ALWAYS prints exactly one line per declared check via chk(),
# regardless of import success or per-case exceptions. This keeps the set of
# emitted checks (and therefore the denominator) CONSTANT for every submission.
RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>/dev/null
import sys

ok = True
try:
    from lru_cache import LRUCache
except Exception as e:
    print("IMPORT_ERR", repr(e)[:80], file=sys.stderr)
    ok = False

def chk(name, fn):
    # Always emit a line. Import-broken => 0. Per-case exception => 0.
    if not ok:
        print(name, 0, "import_failed")
        return
    try:
        print(name, 1 if fn() else 0)
    except Exception as ex:
        # sanitized + truncated; rubric strips quotes/backslashes too
        msg = repr(ex)[:50].replace('"', "'").replace("\\", " ")
        print(name, 0, msg)

print("imports", 1 if ok else 0)

# Standard LeetCode trace on a capacity-2 cache.
def case_g1():
    c = LRUCache(2)
    c.put(1, 1); c.put(2, 2)
    return c.get(1) == 1
chk("g1", case_g1)

def case_g2():
    c = LRUCache(2)
    c.put(1, 1); c.put(2, 2)
    c.get(1)
    c.put(3, 3)  # evicts 2 (LRU)
    return c.get(2) is None
chk("g2", case_g2)

def case_g3():
    c = LRUCache(2)
    c.put(1, 1); c.put(2, 2)
    c.get(1)
    c.put(3, 3)
    c.put(4, 4)  # evicts 1
    return c.get(1) is None
chk("g3", case_g3)

def case_g4():
    c = LRUCache(2)
    c.put(1, 1); c.put(2, 2)
    c.get(1)
    c.put(3, 3)
    c.put(4, 4)
    return c.get(3) == 3
chk("g4", case_g4)

def case_g5():
    c = LRUCache(2)
    c.put(1, 1); c.put(2, 2)
    c.get(1)
    c.put(3, 3)
    c.put(4, 4)
    return c.get(4) == 4
chk("g5", case_g5)

def case_len():
    c = LRUCache(2)
    c.put(1, 1); c.put(2, 2); c.put(3, 3)
    return len(c) == 2
chk("len", case_len)

# Updating an existing key marks it most-recently-used.
def case_update_recent():
    c = LRUCache(2)
    c.put('a', 1); c.put('b', 2); c.put('a', 3)  # a now most recent
    c.put('c', 4)  # should evict b, not a
    return c.get('b') is None and c.get('a') == 3
chk("update_recent", case_update_recent)

# __contains__ reports membership.
def case_contains():
    c = LRUCache(2)
    c.put('x', 1); c.put('y', 2)
    return ('x' in c) and ('y' in c)
chk("contains", case_contains)

# Membership check must NOT change recency: x stays LRU and is evicted.
def case_contains_no_touch():
    c = LRUCache(2)
    c.put('x', 1); c.put('y', 2)
    ('x' in c)  # touch via membership
    c.put('z', 3)  # should still evict x (the LRU)
    return ('x' not in c) and ('y' in c) and ('z' in c)
chk("contains_no_touch", case_contains_no_touch)

# Capacity 0/negative must raise ValueError.
def case_invalid_cap():
    try:
        LRUCache(0)
        return False
    except ValueError:
        return True
chk("invalid_cap", case_invalid_cap)
PY
)
echo "$RES" >&2

# Add every emitted behavioral line at its weight. chk() guarantees one line per
# declared check, so the denominator is identical for every submission.
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(printf '%s' "$line" | awk '{print $1}')
  pass=$(printf '%s' "$line" | awk '{print $2}')
  note=$(printf '%s' "$line" | cut -d' ' -f3-)
  [[ "$name" == "imports" ]] && { add "imports" "$pass" 5 "$note"; continue; }
  add "$name" "$pass" 7 "$note"
done < <(printf '%s\n' "$RES")

# If the python block failed to run at all (e.g. gtimeout/python missing) it
# would emit nothing and collapse the denominator. Guard against that: ensure
# every declared check is present, padding any missing one with pass=0.
declared=(imports g1 g2 g3 g4 g5 len update_recent contains contains_no_touch invalid_cap)
have_check() {
  local target="$1" c name rest
  for c in ${checks[@]+"${checks[@]}"}; do
    IFS=$'\t' read -r name rest <<<"$c"
    [[ "$name" == "$target" ]] && return 0
  done
  return 1
}
for d in "${declared[@]}"; do
  if ! have_check "$d"; then
    if [[ "$d" == "imports" ]]; then add "imports" 0 5 "not_emitted"; else add "$d" 0 7 "not_emitted"; fi
  fi
done

total=0; gained=0
{
  printf '{\n  "checks": [\n'
  first=1
  for c in ${checks[@]+"${checks[@]}"}; do
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
