#!/bin/bash
# Installs the graphify CLI in cloud sessions so the graphify hooks and skill work.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

if ! command -v graphify >/dev/null 2>&1; then
  pip install --quiet graphifyy >/dev/null 2>&1 \
    || pip install --quiet --break-system-packages graphifyy >/dev/null 2>&1
fi

# Refresh the code graph (AST only, no API cost).
cd "${CLAUDE_PROJECT_DIR:-.}"
graphify update . >/dev/null 2>&1 || true
