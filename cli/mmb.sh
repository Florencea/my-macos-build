#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "mmb: Open my-machine-build workspace in Visual Studio Code"
  exit 0
fi

REPO_ROOT="$(cd "$(dirname "$(realpath "$0")")/.." && pwd)"
exec code "$REPO_ROOT"
