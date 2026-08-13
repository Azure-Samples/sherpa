#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAMP_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

PIP_INDEX_URL=$(cd "$CAMP_DIR" && azd env get-value PIP_INDEX_URL 2>/dev/null || true)
if [ -n "$PIP_INDEX_URL" ]; then
    export UV_INDEX_URL="$PIP_INDEX_URL"
fi

cd "$SCRIPT_DIR"
uv sync --quiet
uv run python foundry_tools.py setup
