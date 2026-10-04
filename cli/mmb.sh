#!/bin/zsh
emulate -L zsh
set -euo pipefail

# Description: Open current workspace in Visual Studio Code
# Usage: mmb
# Example: mmb

# 1. Parse arguments
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "mmb: Open current my-macos-build workspace in Visual Studio Code"
  echo "Usage: mmb"
  exit 0
fi

# 2. Check required tools
for cmd in code; do
  if ! (($+commands[$cmd])); then
    echo "Error: $cmd is not installed" >&2
    exit 1
  fi
done

# 2. Open workspace in Visual Studio Code
code "${0:A:h:h}"
