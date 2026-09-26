#!/bin/zsh
set -o errexit
set -o nounset
set -o pipefail

# Description: Backup and sync browser extension configuration files
# Usage: ebk
# Example: ebk

# 1. Check required tools
for cmd in git jq; do
  command -v "$cmd" &>/dev/null || {
    echo "Error: $cmd is not installed" >&2
    exit 1
  }
done

# 2. Resolve configuration directory
CONFIG_HOME="${0:A:h:h}/configs"

# 3. Define backup helper functions
commit_file() {
  local file="${1:-}"
  (
    cd "$CONFIG_HOME"
    git add "$file"
    if [[ -n "$(git status --porcelain "$file")" ]]; then
      git commit -q -m "feat: Update $file by ebk"
      git push -q
      printf "Backup %s ok\n" "$file"
    fi
  )
}

copy() {
  local file_path="${1:-}"
  local file_name="${2:-}"
  if [[ -f "$file_path" ]]; then
    cp "$file_path" "$CONFIG_HOME/$file_name"
    commit_file "$file_name"
  fi
}

backup() {
  local file_pattern="${1:-}"
  local file_name="${2:-}"
  local -a matches
  matches=($HOME/Downloads/$~file_pattern(N))
  local file_backup="${matches[1]:-}"
  if [[ -n "$file_backup" && -f "$file_backup" ]]; then
    mv "$file_backup" "$CONFIG_HOME/$file_name"
    commit_file "$file_name"
  fi
}

backupjson() {
  local file_pattern="${1:-}"
  local file_name="${2:-}"
  local -a matches
  matches=($HOME/Downloads/$~file_pattern(N))
  local file_backup="${matches[1]:-}"
  if [[ -n "$file_backup" && -f "$file_backup" ]]; then
    jq . "$file_backup" >"$CONFIG_HOME/$file_name"
    rm -f "$file_backup"
    commit_file "$file_name"
  fi
}

# 4. Backup extension configurations
backup "my-ublock-backup*.txt" "ubo-config.txt"
backupjson "my-ubol-settings.json" "ubol-config.json"
backupjson "ubol-config.json" "ubol-config.json"
backupjson "ubol-config-desktop.json" "ubol-config-desktop.json"
backupjson "ubol-config-mobile.json" "ubol-config-mobile.json"
backupjson "immersive-translate-config-with-terms-*.json" "immersive-translate-config.json"
backupjson "tampermonkey-backup-*.txt" "tampermonkey.json"
backupjson "tongwentang-*.json" "tongwentang.json"
backupjson "stylus-*.json" "stylus.json"
