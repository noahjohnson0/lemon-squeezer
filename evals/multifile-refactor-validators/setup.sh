#!/usr/bin/env bash
# Drop the duplicated validators package into the workspace.
set -u
WS="$1"; ED="$2"
mkdir -p "$WS/validators"
cp "$ED/files/validators/__init__.py"      "$WS/validators/__init__.py"
cp "$ED/files/validators/api.py"           "$WS/validators/api.py"
cp "$ED/files/validators/email_field.py"   "$WS/validators/email_field.py"
cp "$ED/files/validators/phone_field.py"   "$WS/validators/phone_field.py"
cp "$ED/files/validators/postcode_field.py" "$WS/validators/postcode_field.py"
cp "$ED/files/validators/name_field.py"    "$WS/validators/name_field.py"
