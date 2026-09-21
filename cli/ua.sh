#!/bin/zsh
set -o errexit
set -o nounset
set -o pipefail

# Description: Upgrade Homebrew formulas, update Node.js (Active LTS), and sync all git repositories in workspace
# Usage: ua
# Example: ua

# 1. Check required tools
for cmd in brew curl git jq; do
  command -v "$cmd" &>/dev/null || {
    echo "Error: $cmd is not installed" >&2
    exit 1
  }
done

# 2. Upgrade Homebrew packages
cd "$HOME"
# Disable greedy upgrades to prevent updating auto-updating apps (e.g. google-chrome)
HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_ASK=1 HOMEBREW_AUTO_UPDATE_QUIET=1 HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS=1 brew upgrade
HOMEBREW_NO_ENV_HINTS=1 brew cleanup

# 3. Update Node.js (Active LTS)
OPT_NODE_DIR="$HOME/.local/opt"
CURRENT_VERSION="$("$OPT_NODE_DIR/node/bin/node" -v 2>/dev/null || node -v 2>/dev/null || echo "")"

LTS_VER="$(curl -fsSL https://nodejs.org/dist/index.json 2>/dev/null | jq -r 'map(select(.lts != false)) | .[0].version' 2>/dev/null || echo "")"

if [[ -n "$LTS_VER" && "$LTS_VER" != "null" ]]; then
  if [[ "$CURRENT_VERSION" != "$LTS_VER" || ! -x "$OPT_NODE_DIR/node/bin/node" ]]; then
    printf "Updating Node.js: local %s -> remote %s\n" "${CURRENT_VERSION:-none}" "$LTS_VER"
    mkdir -p "$OPT_NODE_DIR"
    TMP_DIR="$(mktemp -d -t node_update)"
    trap 'rm -rf "$TMP_DIR" "$OPT_NODE_DIR/node.tmp.$$"' EXIT INT TERM HUP

    TARBALL="node-${LTS_VER}-darwin-arm64.tar.gz"
    curl -fsSL "https://nodejs.org/dist/${LTS_VER}/${TARBALL}" -o "$TMP_DIR/$TARBALL"
    TARGET_DIR="$OPT_NODE_DIR/node-${LTS_VER}"
    rm -rf "$TARGET_DIR"
    mkdir -p "$TARGET_DIR"
    tar -xzf "$TMP_DIR/$TARBALL" -C "$TARGET_DIR" --strip-components 1

    ln -s "node-${LTS_VER}" "$OPT_NODE_DIR/node.tmp.$$"
    mv -f "$OPT_NODE_DIR/node.tmp.$$" "$OPT_NODE_DIR/node"

    # Clean up older node-v* directories under $HOME/.local/opt
    for dir in "$OPT_NODE_DIR"/node-v*(N/); do
      if [[ "$dir" != "$TARGET_DIR" ]]; then
        rm -rf "$dir"
      fi
    done

    rm -rf "$TMP_DIR"
    trap - EXIT INT TERM HUP

    "$OPT_NODE_DIR/node/bin/npm" config set audit false engine-strict true fund false ignore-scripts true install-strategy linked save-exact true strict-peer-deps true
  fi
  CURRENT_VERSION="$("$OPT_NODE_DIR/node/bin/node" -v 2>/dev/null || echo "$LTS_VER")"
  NPM_VERSION="$("$OPT_NODE_DIR/node/bin/npm" -v 2>/dev/null || echo "n/a")"
else
  printf "Warning: Failed to fetch remote Node.js LTS version. Skipping Node.js update.\n" >&2
  NPM_VERSION="$("$OPT_NODE_DIR/node/bin/npm" -v 2>/dev/null || npm -v 2>/dev/null || echo "n/a")"
fi

# 4. Print active Node.js and npm versions
printf "\nnode: %s, npm: %s\n\n" "$CURRENT_VERSION" "$NPM_VERSION"

# 5. Sync git projects in workspace
PROJECTS_DIR="${0:A:h:h:h}"

if cd "$PROJECTS_DIR"; then
  for PROJECT in *(N/); do
    if [[ -d "$PROJECT/.git" ]]; then
      (git -C "$PROJECT" pull --all --quiet && printf "Sync %s ok\n" "$PROJECT") &
    fi
  done
  wait
fi
