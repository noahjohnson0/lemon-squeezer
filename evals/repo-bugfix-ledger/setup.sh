#!/usr/bin/env bash
# setup.sh <workspace> <eval-dir>
WS="$1"; ED="$2"
mkdir -p "$WS/ledger"
cp "$ED/files/ledger/__init__.py" "$WS/ledger/__init__.py"
cp "$ED/files/ledger/account.py" "$WS/ledger/account.py"
cp "$ED/files/ledger/posting.py" "$WS/ledger/posting.py"
cp "$ED/files/ledger/report.py"  "$WS/ledger/report.py"
