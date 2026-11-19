#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "ua: Upgrade Homebrew, Node.js LTS via fnm, and sync workspace git repositories"
  exit 0
fi

cd "$HOME"
HOMEBREW_NO_ENV_HINTS=1 \
  HOMEBREW_NO_ASK=1 \
  HOMEBREW_AUTO_UPDATE_QUIET=1 \
  HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS=1 \
  brew upgrade
HOMEBREW_NO_ENV_HINTS=1 brew cleanup

REMOTE_VERSION="$(fnm list-remote --lts --latest 2>/dev/null || true)"
REMOTE_VERSION="${REMOTE_VERSION%% *}"
CURRENT_VERSION="$(node -v 2>/dev/null || true)"

if [[ -n "$REMOTE_VERSION" && "$REMOTE_VERSION" != "$CURRENT_VERSION" ]]; then
  printf "Updating Node.js: %s -> %s\n" "${CURRENT_VERSION:-none}" "$REMOTE_VERSION"
  fnm install "$REMOTE_VERSION" >/dev/null
  fnm default "$REMOTE_VERSION" >/dev/null
  if [[ -n "$CURRENT_VERSION" ]]; then
    fnm uninstall "$CURRENT_VERSION" >/dev/null 2>&1 || true
  fi
  CURRENT_VERSION="$REMOTE_VERSION"
  NPM_VERSION="$(fnm exec --using="$REMOTE_VERSION" npm -v 2>/dev/null || echo "n/a")"
else
  NPM_VERSION="$(npm -v 2>/dev/null || echo "n/a")"
fi

printf "\nnode: %s, npm: %s\n\n" "${CURRENT_VERSION:-none}" "$NPM_VERSION"

PROJECTS_DIR="$(cd "$(dirname "$(realpath "$0")")/../.." && pwd)"
if cd "$PROJECTS_DIR"; then
  for dir in */; do
    [[ -d "$dir" ]] || continue
    name="${dir%/}"
    if [[ -d "$dir/.git" ]]; then
      (git -C "$dir" pull --all --quiet && printf "Sync %s ok\n" "$name") &
    fi
  done
  wait
fi
