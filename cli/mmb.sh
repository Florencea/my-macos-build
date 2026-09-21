#!/bin/zsh
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
code "${0:A:h:h}"
