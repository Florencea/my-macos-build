#!/usr/bin/env bash
# Open my-macos-build workspace in Visual Studio Code
# Usage: mmb
set -euo pipefail

exec code "$(cd "$(dirname "$(realpath "$0")")/.." && pwd)"
