#!/bin/bash
# Select the host's configured Python package index for container builds.

set -e

PIP_INDEX_SOURCE="configured environment"

if [ -z "${PIP_INDEX_URL:-}" ]; then
    PYTHON_CMD=""
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_CMD="python3"
    elif command -v python >/dev/null 2>&1; then
        PYTHON_CMD="python"
    fi

    DETECTED_PIP_INDEX_URL=""
    if [ -n "$PYTHON_CMD" ]; then
        PIP_CONFIG_LIST=$(env -u PIP_INDEX_URL "$PYTHON_CMD" -m pip config list 2>/dev/null || true)
        DETECTED_PIP_INDEX_URL=$(printf '%s\n' "$PIP_CONFIG_LIST" | sed -n "s/^global\.index-url='\(.*\)'$/\1/p" | head -n 1)
    fi

    if [ -n "$DETECTED_PIP_INDEX_URL" ]; then
        PIP_INDEX_URL="$DETECTED_PIP_INDEX_URL"
        PIP_INDEX_SOURCE="host pip configuration"
    else
        PIP_INDEX_URL="https://pypi.org/simple"
        PIP_INDEX_SOURCE="public PyPI default"
    fi
fi

case "$PIP_INDEX_URL" in
    http://*|https://*) ;;
    *)
        echo "Error: PIP_INDEX_URL must be an absolute HTTP or HTTPS URL."
        exit 1
        ;;
esac

PIP_INDEX_AUTHORITY=${PIP_INDEX_URL#*://}
PIP_INDEX_AUTHORITY=${PIP_INDEX_AUTHORITY%%/*}
case "$PIP_INDEX_AUTHORITY" in
    *@*)
        echo "Error: PIP_INDEX_URL must not contain embedded credentials."
        exit 1
        ;;
esac

PIP_INDEX_HOST=${PIP_INDEX_AUTHORITY%%:*}
if [ -z "$PIP_INDEX_HOST" ]; then
    echo "Error: PIP_INDEX_URL must include a hostname."
    exit 1
fi

azd env set PIP_INDEX_URL "$PIP_INDEX_URL"
echo "Python package index: $PIP_INDEX_HOST ($PIP_INDEX_SOURCE)"