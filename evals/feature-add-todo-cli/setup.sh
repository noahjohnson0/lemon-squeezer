#!/usr/bin/env bash
# setup.sh <workspace> <eval-dir>
WS="$1"; ED="$2"
mkdir -p "$WS/app"
cp "$ED/files/app/storage.py" "$WS/app/storage.py"
cp "$ED/files/app/cli.py" "$WS/app/cli.py"
