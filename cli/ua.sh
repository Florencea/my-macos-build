#!/bin/zsh
emulate -L zsh
set -euo pipefail

# Description: Upgrade Homebrew formulas, update Node.js (Active LTS via Vite+), and sync all git repositories in workspace
# Usage: ua
# Example: ua

# 1. Check required tools
for cmd in brew curl git jq vp; do
  if ! (($+commands[$cmd])); then
    echo "Error: $cmd is not installed" >&2
    exit 1
  fi
done

# 2. Upgrade Homebrew packages
cd "$HOME"
# Disable greedy upgrades to prevent updating auto-updating apps (e.g. google-chrome)
HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_ASK=1 HOMEBREW_AUTO_UPDATE_QUIET=1 HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS=1 brew upgrade
HOMEBREW_NO_ENV_HINTS=1 brew cleanup

# 3. Update Node.js & Vite+ Toolchain (Active LTS via vp)
# Pipe through cat to bypass repetitive interactive TTY banner while preserving output
vp upgrade | cat
vp env default lts | cat
vp env install lts | cat
vp env clean | cat

# Clean up legacy standalone Node.js if present
if [[ -d "$HOME/.local/opt/node" ]]; then
  rm -rf "$HOME/.local/opt"/node*(N)
  rmdir "$HOME/.local/opt" 2>/dev/null || true
fi

CURRENT_NODE="$(vp node -v 2>/dev/null || node -v 2>/dev/null || echo "none")"
CURRENT_VP="$(vp --version 2>/dev/null | rg '^vp v' || echo "")"
printf "\n%s\nnode: %s\n\n" "$CURRENT_VP" "$CURRENT_NODE"

# 4. Sync git projects in workspace
PROJECTS_DIR="${0:A:h:h:h}"

if cd "$PROJECTS_DIR"; then
  for PROJECT in *(N/); do
    if [[ -d "$PROJECT/.git" ]]; then
      (
        if git -C "$PROJECT" pull --all --quiet; then
          printf "Sync %s ok\n" "$PROJECT"
        else
          printf "Sync %s failed\n" "$PROJECT" >&2
        fi
      ) &
    fi
  done
  wait
fi
