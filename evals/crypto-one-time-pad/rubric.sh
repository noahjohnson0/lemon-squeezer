#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

F="$WS/otp.py"
add "file:otp.py" "$([[ -f "$F" ]] && echo 1 || echo 0)" 5

if [[ -f "$F" ]]; then
  RES=$(python3 - "$WS" <<'PY' 2>&1
import sys, importlib.util
ws = sys.argv[1]
spec = importlib.util.spec_from_file_location("o", f"{ws}/otp.py")
mod  = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
except Exception as e:
    print(f"IMPORT_ERROR: {repr(e)[:120]}"); sys.exit(0)

# Known XOR: "HELLO" ^ "ABCDE" = ?
pt = b"HELLO"; key = b"ABCDE"
expected_xor = bytes(a ^ b for a, b in zip(pt, key))
try:
    ct = mod.xor_encrypt(pt, key)
    enc_ok = (ct == expected_xor)
except Exception:
    enc_ok = False

try:
    rt = mod.xor_decrypt(ct, key)
    rt_ok = (rt == pt)
except Exception:
    rt_ok = False

# Length mismatch raises
short_ok = 0
try:
    mod.xor_encrypt(b"HELLO", b"AB")
except ValueError:
    short_ok = 1
except Exception:
    short_ok = 0

# Empty inputs OK
try:
    empty_ok = (mod.xor_encrypt(b"", b"") == b"")
except Exception:
    empty_ok = False

# Hex round-trip
try:
    h = mod.hex_encode(b"\x00\x01\xff")
    hex_round_ok = (mod.hex_decode(h) == b"\x00\x01\xff" and ":" not in h and h == h.lower())
except Exception:
    hex_round_ok = False

# Key generation uses secrets
import secrets
gen_correct_length = False
gen_uses_secrets = False
try:
    k1 = mod.generate_key(32)
    gen_correct_length = isinstance(k1, bytes) and len(k1) == 32
    # Two calls should differ
    k2 = mod.generate_key(32)
    gen_unique = k1 != k2
    # Quick source inspection: does the file mention 'secrets'?
    src = open(f"{ws}/otp.py").read()
    gen_uses_secrets = "secrets" in src
except Exception:
    gen_unique = False

print(f"enc={int(enc_ok)} dec={int(rt_ok)} short={short_ok} empty={int(empty_ok)} hex={int(hex_round_ok)} gen_len={int(gen_correct_length)} gen_unique={int(gen_unique)} uses_secrets={int(gen_uses_secrets)}")
PY
)
  echo "DEBUG: $RES" >&2

  if echo "$RES" | grep -q "IMPORT_ERROR"; then
    add "imports" 0 10 "$(echo "$RES" | head -1 | cut -c1-100)"
  else
    add "imports" 1 5
    echo "$RES" | grep -q "enc=1"          && add "xor_encrypt"        1 15 || add "xor_encrypt"        0 15
    echo "$RES" | grep -q "dec=1"          && add "xor_decrypt"        1 10 || add "xor_decrypt"        0 10
    echo "$RES" | grep -q "short=1"        && add "rejects_len_mismatch" 1 15 || add "rejects_len_mismatch" 0 15
    echo "$RES" | grep -q "empty=1"        && add "handles_empty"      1 5  || add "handles_empty"      0 5
    echo "$RES" | grep -q "hex=1"          && add "hex_roundtrip"      1 10 || add "hex_roundtrip"      0 10
    echo "$RES" | grep -q "gen_len=1"      && add "generate_key_length" 1 10 || add "generate_key_length" 0 10
    echo "$RES" | grep -q "gen_unique=1"   && add "generate_key_random" 1 10 || add "generate_key_random" 0 10
    echo "$RES" | grep -q "uses_secrets=1" && add "uses_secrets_module" 1 15 || add "uses_secrets_module" 0 15 "use secrets, not random"
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
