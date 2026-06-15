#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/app.py"
add "file:app.py" "$([[ -f "$T" ]] && echo 1 || echo 0)" 5

if [[ -f "$T" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && add "compiles" 1 5 || add "compiles" 0 5

  # Static check: must use ? placeholders, must NOT have f-string SQL with name
  if grep -qE "execute\([^)]*['\"]?\?['\"]?" "$T"; then add "uses_placeholders" 1 15; else add "uses_placeholders" 0 15; fi
  if grep -qE "f['\"][^'\"]*WHERE[^'\"]*\{name\}" "$T"; then
    add "removed_fstring_sql" 0 10 "still has f-string SQL with {name}"
  else
    add "removed_fstring_sql" 1 10
  fi

  # Behaviour: import lookup, run normal + injection payloads
  RES=$(cd "$WS" && gtimeout 10 python3 - <<'PY' 2>&1
import sys, importlib.util
spec = importlib.util.spec_from_file_location("app", "app.py")
m = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(m)
except Exception as e:
    print("LOAD_ERR", e); sys.exit(1)

if not hasattr(m, "init_db") or not hasattr(m, "lookup"):
    print("API_ERR missing init_db or lookup"); sys.exit(1)

con = m.init_db()
def n(rows): return len(rows) if rows is not None else -1

print("alice_count",   n(m.lookup(con, "alice")))
print("bob_count",     n(m.lookup(con, "bob")))
print("missing_count", n(m.lookup(con, "nobody")))

try:
    inj1 = m.lookup(con, "' OR '1'='1")
    print("inj1_count", n(inj1))
except Exception as e:
    print("inj1_count -2", repr(e))
try:
    inj2 = m.lookup(con, "alice'; DROP TABLE users; --")
    print("inj2_count", n(inj2))
except Exception as e:
    print("inj2_count -2", repr(e))

# Sanity: data still there after attempted injection
print("post_drop_alice", n(m.lookup(con, "alice")))
PY
)
  echo "$RES" >&2
  get() { echo "$RES" | awk -v k="$1" '$1==k {print $2}' ; }
  alice_count=$(get alice_count)
  bob_count=$(get bob_count)
  missing_count=$(get missing_count)
  inj1_count=$(get inj1_count)
  inj2_count=$(get inj2_count)
  post_drop=$(get post_drop_alice)

  [[ "$alice_count"   == "1" ]] && add "alice_returns_1_row" 1 10 || add "alice_returns_1_row" 0 10 "got $alice_count"
  [[ "$bob_count"     == "1" ]] && add "bob_returns_1_row"   1 10 || add "bob_returns_1_row"   0 10 "got $bob_count"
  [[ "$missing_count" == "0" ]] && add "missing_returns_0"   1 5  || add "missing_returns_0"   0 5  "got $missing_count"
  [[ "$inj1_count"    == "0" ]] && add "blocks_or_quote_eq_quote" 1 20 || add "blocks_or_quote_eq_quote" 0 20 "got $inj1_count (should be 0; if all 3 rows: still vulnerable)"
  # inj2: drop-table payload should either return 0 rows OR raise - both fine; what matters is data still there
  if [[ "$inj2_count" == "0" || "$inj2_count" == "-2" ]]; then add "blocks_drop_table_payload" 1 10
  else add "blocks_drop_table_payload" 0 10 "got $inj2_count"; fi
  [[ "$post_drop"     == "1" ]] && add "data_intact_after_attack" 1 10 || add "data_intact_after_attack" 0 10 "alice gone after injection: $post_drop"
else
  for n in compiles uses_placeholders removed_fstring_sql alice_returns_1_row bob_returns_1_row missing_returns_0 blocks_or_quote_eq_quote blocks_drop_table_payload data_intact_after_attack; do
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
