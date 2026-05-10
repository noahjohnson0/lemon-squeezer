#!/usr/bin/env bash
# setup.sh <workspace> <eval-dir>
WS="$1"; ED="$2"
cp "$ED/files/csv_total.py" "$WS/csv_total.py"
cp "$ED/files/data.csv" "$WS/data.csv"
