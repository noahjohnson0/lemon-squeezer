#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

F="$WS/break_caesar.py"
add "file:break_caesar.py" "$([[ -f "$F" ]] && echo 1 || echo 0)" 5

if [[ -f "$F" ]]; then
  RES=$(python3 - "$WS" <<'PY' 2>&1
import sys, importlib.util
ws = sys.argv[1]
spec = importlib.util.spec_from_file_location("bc", f"{ws}/break_caesar.py")
mod  = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
except Exception as e:
    print(f"IMPORT_ERROR: {repr(e)[:120]}"); sys.exit(0)

def encrypt(s, k):
    out = []
    for c in s:
        if 'A' <= c <= 'Z':
            out.append(chr((ord(c) - ord('A') + k) % 26 + ord('A')))
        elif 'a' <= c <= 'z':
            out.append(chr((ord(c) - ord('a') + k) % 26 + ord('a')))
        else:
            out.append(c)
    return ''.join(out)

# Need long-enough ciphertexts so frequency analysis works
plaintexts = [
    ("The quick brown fox jumps over the lazy dog and many other common english words.", 3),
    ("Cryptography is the practice of secure communication in the presence of adversaries.", 13),
    ("To be or not to be that is the question whether tis nobler in the mind to suffer.", 7),
    ("All happy families are alike each unhappy family is unhappy in its own way always.", 19),
]
ok_shift = 0; ok_text = 0
for (pt, shift) in plaintexts:
    ct = encrypt(pt, shift)
    try:
        s, recovered = mod.break_caesar(ct)
        if s == shift: ok_shift += 1
        if recovered == pt: ok_text += 1
        elif recovered.lower() == pt.lower(): ok_text += 1  # case preservation optional
    except Exception as e:
        print(f"err: {repr(e)[:80]}")

print(f"shifts={ok_shift}/{len(plaintexts)} texts={ok_text}/{len(plaintexts)}")
PY
)
  echo "DEBUG: $RES" >&2

  if echo "$RES" | grep -q "IMPORT_ERROR"; then
    add "imports" 0 10 "$(echo "$RES" | head -1 | cut -c1-100)"
  else
    add "imports" 1 10
    sh=$(echo "$RES" | grep -oE 'shifts=[0-9]+' | cut -d= -f2)
    txt=$(echo "$RES" | grep -oE 'texts=[0-9]+' | cut -d= -f2)
    if   [[ "${sh:-0}" -ge 4 ]]; then add "recovers_shift_all"  1 40 "4/4"
    elif [[ "${sh:-0}" -ge 3 ]]; then add "recovers_shift_all"  1 25 "$sh/4"
    elif [[ "${sh:-0}" -ge 2 ]]; then add "recovers_shift_all"  1 12 "$sh/4"
    else                              add "recovers_shift_all"  0 40 "$sh/4"
    fi
    if   [[ "${txt:-0}" -ge 4 ]]; then add "recovers_text_all"  1 35 "4/4"
    elif [[ "${txt:-0}" -ge 3 ]]; then add "recovers_text_all"  1 22 "$txt/4"
    elif [[ "${txt:-0}" -ge 2 ]]; then add "recovers_text_all"  1 10 "$txt/4"
    else                               add "recovers_text_all"  0 35 "$txt/4"
    fi
    add "returns_tuple" 1 10 ""  # got this far means tuple-unpacking worked
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
