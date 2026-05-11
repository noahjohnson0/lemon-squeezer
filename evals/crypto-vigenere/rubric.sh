#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

F="$WS/vigenere.py"
add "file:vigenere.py" "$([[ -f "$F" ]] && echo 1 || echo 0)" 5

if [[ -f "$F" ]]; then
  RES=$(python3 - "$WS" <<'PY' 2>&1
import sys, importlib.util
ws = sys.argv[1]
spec = importlib.util.spec_from_file_location("v", f"{ws}/vigenere.py")
mod  = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
except Exception as e:
    print(f"IMPORT_ERROR: {repr(e)[:120]}"); sys.exit(0)

cases = [
    ("ATTACK AT DAWN", "LEMON",       "LXFOPV EF RNHR"),
    ("HELLO WORLD",    "KEY",         "RIJVS UYVJN"),
    ("Hello, World!",  "KEY",         "Rijvs, Uyvjn!"),
    ("xyz",            "ABC",         "xzb"),
]
enc_ok = 0; dec_ok = 0
for pt, k, ct in cases:
    try:
        got = mod.encrypt(pt, k)
        if got == ct: enc_ok += 1
        else: print(f"enc_fail: '{pt}' k='{k}' got='{got}' want='{ct}'")
    except Exception as e:
        print(f"enc_err: {repr(e)[:80]}")
    try:
        got2 = mod.decrypt(ct, k)
        if got2 == pt: dec_ok += 1
        else: print(f"dec_fail: '{ct}' k='{k}' got='{got2}' want='{pt}'")
    except Exception as e:
        print(f"dec_err: {repr(e)[:80]}")

# Error cases
err_empty = 0; err_bad = 0
try: mod.encrypt("HELLO", "")
except ValueError: err_empty = 1
except Exception: pass
try: mod.encrypt("HELLO", "12!")
except ValueError: err_bad = 1
except Exception: pass

print(f"enc={enc_ok}/{len(cases)} dec={dec_ok}/{len(cases)} err_empty={err_empty} err_bad={err_bad}")
PY
)
  echo "DEBUG: $RES" >&2

  if echo "$RES" | grep -q "IMPORT_ERROR"; then
    add "imports" 0 10 "$(echo "$RES" | head -1 | cut -c1-100)"
  else
    add "imports" 1 5
    enc=$(echo "$RES" | grep -oE 'enc=[0-9]+' | cut -d= -f2)
    [[ "${enc:-0}" -ge 4 ]] && add "encrypt_4/4" 1 25 || \
      ( [[ "${enc:-0}" -ge 2 ]] && add "encrypt_4/4" 1 12 "$enc/4" || add "encrypt_4/4" 0 25 "$enc/4" )
    dec=$(echo "$RES" | grep -oE 'dec=[0-9]+' | cut -d= -f2)
    [[ "${dec:-0}" -ge 4 ]] && add "decrypt_4/4" 1 25 || \
      ( [[ "${dec:-0}" -ge 2 ]] && add "decrypt_4/4" 1 12 "$dec/4" || add "decrypt_4/4" 0 25 "$dec/4" )
    echo "$RES" | grep -q "err_empty=1" && add "rejects_empty_key" 1 10 || add "rejects_empty_key" 0 10
    echo "$RES" | grep -q "err_bad=1"   && add "rejects_bad_key"   1 10 || add "rejects_bad_key"   0 10
  fi
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
