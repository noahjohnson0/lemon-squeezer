#!/usr/bin/env bash
set -u
WS="${1:?workspace}"
declare -a checks
# sanitize: strip backslashes and double-quotes from notes so the JSON stays valid
add() {
  local n="$1" p="$2" w="$3" note="${4:-}"
  [[ "$p" != "1" ]] && p=0
  note="${note//\\/}"
  note="${note//\"/\'}"
  checks+=("$(printf '%s\t%s\t%s\t%s' "$n" "$p" "$w" "$note")")
}

T="$WS/spectrum.py"
file_ok=0; [[ -f "$T" ]] && file_ok=1
add "file:spectrum.py" "$file_ok" 5

compile_ok=0
if [[ "$file_ok" == "1" ]]; then
  python3 -m py_compile "$T" 2>/dev/null && compile_ok=1
fi
add "compiles" "$compile_ok" 5

# Behavioral block ALWAYS runs and ALWAYS emits exactly these lines:
#   imports dom_50hz dom_440hz dom_dc_reject spec_len spec_first_dc spec_last_nyq empty_raises
# chk() prints pass=0 (never aborts/skips) on import failure or any per-case exception,
# so the denominator is identical for every submission.
RES=$(cd "$WS" && gtimeout 15 python3 - <<'PY' 2>&1
import sys, math

ok = True
try:
    from spectrum import magnitude_spectrum, dominant_freq
except Exception as e:
    print("IMPORT_ERR", repr(e)[:80], file=sys.stderr)
    ok = False

def san(s):
    return str(s).replace("\\", "").replace('"', "'").replace("\n", " ")

def chk(name, fn, note=""):
    if not ok:
        print(name, 0, "import_failed")
        return
    try:
        passed, n = fn()
        print(name, 1 if passed else 0, san(n))
    except Exception as ex:
        print(name, 0, san(repr(ex)[:50]))

print("imports", 1 if ok else 0, "ok" if ok else "import_failed")

# 50 Hz pure tone, fs=1000, N=1024 -> bin 51 (51*1000/1024=49.80 Hz)
fs, N = 1000.0, 1024
x = [math.sin(2*math.pi*50*n/fs) for n in range(N)]
def c_dom50():
    f = dominant_freq(x, fs)
    bin_freq = 51 * fs / N
    return abs(f - bin_freq) < fs/N, "got=%.3f expected~%.3f" % (f, bin_freq)
chk("dom_50hz", c_dom50)

# 440 Hz sine, fs=8000, N=4096 -> bin 225 (225*8000/4096=439.45)
fs2, N2 = 8000.0, 4096
x2 = [math.sin(2*math.pi*440*n/fs2) for n in range(N2)]
def c_dom440():
    f = dominant_freq(x2, fs2)
    return abs(f - 439.45) < 1.0, "got=%.3f" % f
chk("dom_440hz", c_dom440)

# DC offset + tone: must reject DC and find tone
x3 = [5.0 + 0.1*math.sin(2*math.pi*50*n/fs) for n in range(N)]
def c_domdc():
    f = dominant_freq(x3, fs)
    return abs(f - 49.80) < 1.0, "got=%.3f" % f
chk("dom_dc_reject", c_domdc)

# spectrum shape / endpoints
def _spec():
    return magnitude_spectrum(x, fs)
def c_speclen():
    fr, mg = _spec()
    return (len(fr) == N//2+1 and len(mg) == N//2+1), "got=%d" % len(fr)
chk("spec_len", c_speclen)
def c_specdc():
    fr, mg = _spec()
    return abs(fr[0] - 0.0) < 1e-9, "got=%s" % fr[0]
chk("spec_first_dc", c_specdc)
def c_specnyq():
    fr, mg = _spec()
    return abs(fr[-1] - fs/2) < 1e-3, "got=%s" % fr[-1]
chk("spec_last_nyq", c_specnyq)

# zero-length raises ValueError
def c_empty():
    try:
        magnitude_spectrum([], fs)
        return False, "no_raise"
    except ValueError:
        return True, "ValueError"
    except Exception as e:
        return False, san(repr(e)[:40])
chk("empty_raises", c_empty)
PY
)
echo "$RES" >&2

# Fixed set of behavioral checks. Each is filled from RES if present, else scored 0.
# This guarantees a CONSTANT denominator regardless of what python managed to emit.
declare -A bres
declare -A bnote
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name=$(echo "$line" | awk '{print $1}')
  [[ "$name" == "IMPORT_ERR" ]] && continue
  pass=$(echo "$line" | awk '{print $2}')
  note=$(echo "$line" | cut -d' ' -f3-)
  bres["$name"]="$pass"
  bnote["$name"]="$note"
done < <(echo "$RES")

emit() { # name weight
  local n="$1" w="$2" p="${bres[$1]:-0}" note="${bnote[$1]:-not_emitted}"
  add "$n" "$p" "$w" "$note"
}
emit "imports"       8
emit "dom_50hz"      11
emit "dom_440hz"     11
emit "dom_dc_reject" 11
emit "spec_len"      11
emit "spec_first_dc" 11
emit "spec_last_nyq" 11
emit "empty_raises"  11

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
