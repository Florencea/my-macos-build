#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Description: Open current workspace in Visual Studio Code
# Usage: mmb
# Example: mmb

# 1. Check required tools
for cmd in code; do
  command -v "$cmd" &>/dev/null || {
    echo "Error: $cmd is not installed" >&2
    exit 1
  }
done

# 2. Open workspace in Visual Studio Code
SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || realpath "$0")")"
code "$SCRIPT_DIR/../"
