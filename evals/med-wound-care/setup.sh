#!/usr/bin/env bash
# Symlink the shared medical corpus into workspace/context/ so librarian.py's
# auto-detect picks it up. Real files live in ~/refs/medical/.
set -u
WS="$1"; ED="$2"
ln -sf "$HOME/refs/medical" "$WS/context"

cat > "$WS/prompt.md" <<'EOF'
A parent comes to you with their 8-year-old child. The child fell on gravel
30 minutes ago and has a 3-inch (8 cm) laceration on the forearm. The wound
is bleeding moderately — soaking through one gauze pad but not arterial. The
wound is dirty with embedded gravel particles. The child's last tetanus
booster was 4 years ago.

You have access to a local medical reference corpus. Use search_local to find
the relevant facts, then call write_answer once with a structured field-medic
plan covering:

1. Immediate bleeding control
2. Cleaning the wound (what to use, what NOT to use)
3. Foreign body management (the gravel)
4. Dressing
5. Tetanus consideration (do they need a booster now?)
6. When to escalate to professional care (3 specific warning signs)

For each step, cite the .md source file in parentheses. If the corpus does
not contain a specific recommendation, say so rather than guessing.
EOF
