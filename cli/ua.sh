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

PROJECTS_DIR="${0:A:h:h:h}"

# 2. Upgrade Homebrew packages
cd "$HOME"
# Disable greedy upgrades to prevent updating auto-updating apps (e.g. google-chrome)
HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_ASK=1 HOMEBREW_AUTO_UPDATE_QUIET=1 HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS=1 brew upgrade
HOMEBREW_NO_ENV_HINTS=1 brew cleanup

# 3. Update Node.js & Vite+ Toolchain (Active LTS via vp)
vp upgrade | cat

OLD_NODE="$(vp node -v 2>/dev/null || node -v 2>/dev/null || echo "")"
install_out="$(vp env install lts 2>&1 | cat)"
NEW_NODE="$(vp node -v 2>/dev/null || node -v 2>/dev/null || echo "")"

if [[ -n "$OLD_NODE" && "$OLD_NODE" != "$NEW_NODE" ]]; then
  echo "$install_out"
  vp env clean 2>&1 | cat
fi

# Clean up legacy standalone Node.js if present
if [[ -d "$HOME/.local/opt/node" ]]; then
  rm -rf "$HOME/.local/opt"/node*(N)
  rmdir "$HOME/.local/opt" 2>/dev/null || true
fi

printf "\nnode: %s\n\n" "$NEW_NODE"

# 4. Sync git projects in workspace
if cd "$PROJECTS_DIR"; then
  TMPDIR="$(mktemp -d -t ua_sync.XXXXXX)"
  trap 'rm -rf "$TMPDIR"' EXIT INT TERM

  local -i total=0
  for PROJECT in *(N/); do
    if [[ -d "$PROJECT/.git" ]]; then
      ((total += 1))
      (
        local out
        if out="$(git -C "$PROJECT" pull --all 2>&1)"; then
          if [[ "$out" =~ "Updating |Fast-forward" ]]; then
            printf "Sync %s updated\n" "$PROJECT"
            touch "$TMPDIR/${PROJECT}_updated"
          fi
          touch "$TMPDIR/${PROJECT}_ok"
        else
          printf "Sync %s failed\n" "$PROJECT" >&2
          touch "$TMPDIR/${PROJECT}_failed"
        fi
      ) &
    fi
  done
  wait

  local -a updated_files=("$TMPDIR"/*_updated(N))
  local -a failed_files=("$TMPDIR"/*_failed(N))
  local -i updated_count=$#updated_files
  local -i failed_count=$#failed_files

  if ((failed_count == 0)); then
    if ((updated_count == 0)); then
      printf "Sync workspace repositories ok (%d projects up to date)\n" "$total"
    else
      printf "Sync workspace repositories ok (%d updated, %d up to date)\n" "$updated_count" "$((total - updated_count))"
    fi
  fi
fi
