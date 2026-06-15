#!/usr/bin/env bash
# setup.sh <workspace> <eval-dir>
WS="$1"; ED="$2"
cp "$ED/files/engine.py" "$WS/engine.py"
cp "$ED/files/order_workflow.py" "$WS/order_workflow.py"
