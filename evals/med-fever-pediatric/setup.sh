#!/usr/bin/env bash
set -u
WS="$1"; ED="$2"
ln -sf "$HOME/refs/medical" "$WS/context"

cat > "$WS/prompt.md" <<'EOF'
A worried parent calls. Their 18-month-old (weight 11 kg) has a temperature of
102.5°F (39.2°C) measured rectally. The child is otherwise alert, drinking
fluids, and has no rash, neck stiffness, or difficulty breathing. No recent
medication.

Use search_local in the medical corpus to ground your answer, then call
write_answer once with:

1. What temperature qualifies as a fever in this age group?
2. Should the parent give a fever-reducer right now? Which medication, what dose, how often?
   - Cover both options (paracetamol/acetaminophen AND ibuprofen) with their per-kg dosing
   - Be explicit about MAXIMUM single dose and MAXIMUM per-day dose
3. List at least 3 RED-FLAG symptoms that would mean immediate ED visit
4. Hydration / supportive care advice

Cite the corpus filename in parentheses for each fact. If the corpus does not
contain a specific number, say so rather than guessing.
EOF
