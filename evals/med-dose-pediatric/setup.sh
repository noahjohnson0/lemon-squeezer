#!/usr/bin/env bash
set -u
WS="$1"; ED="$2"
ln -sf "$HOME/refs/medical" "$WS/context"

cat > "$WS/prompt.md" <<'EOF'
You are asked to calculate safe pediatric doses for two common antipyretic
analgesics. Use search_local in the medical corpus to ground the numbers.

For EACH of these patients, output:
  - The chosen medication name
  - The per-kg dose calculation (showing the math)
  - The actual mL or mg to give
  - The dosing interval
  - The daily maximum
  - A safety note if the patient is too young for either medication
  - The corpus file you cited

Patient A: 24 months old, weight 12 kg, fever 102°F, no contraindications.
Patient B: 4 months old, weight 6.5 kg, mild fever 100.6°F.
Patient C: 8 years old, weight 28 kg, headache + low-grade fever 100.2°F.

For Patient B, note the relevant age cutoff for ibuprofen.

When done, call write_answer once with the full structured response. If the
corpus doesn't contain a specific number, say so - DO NOT invent doses.
EOF
