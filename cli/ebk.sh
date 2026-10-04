#!/bin/zsh
emulate -L zsh
set -euo pipefail

# Description: Backup and sync browser extension configuration files
# Usage: ebk
# Example: ebk

# 1. Parse arguments
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "ebk: Backup and sync browser extension configuration files"
  echo "Usage: ebk"
  exit 0
fi

# 2. Check required tools
for cmd in git jq; do
  if ! (($+commands[$cmd])); then
    echo "Error: $cmd is not installed" >&2
    exit 1
  fi
done

# 2. Resolve configuration directory
CONFIG_HOME="${0:A:h:h}/configs"
NEED_PUSH=0

# 3. Define backup helper functions
commit_file() {
  local file="${1:-}"
  local has_changes=0
  (
    cd "$CONFIG_HOME"
    git add "$file"
    [[ -n "$(git status --porcelain -- "$file")" ]]
  ) && has_changes=1 || has_changes=0

  if ((has_changes)); then
    (
      cd "$CONFIG_HOME"
      git commit -q -m "feat: Update $file by ebk"
    )
    printf "Backup %s ok\n" "$file"
    NEED_PUSH=1
  else
    printf "Backup %s ok (unchanged)\n" "$file"
  fi
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
  matches=($HOME/Downloads/$~file_pattern(Nom))
  local file_backup="${matches[1]:-}"
  if [[ -n "$file_backup" && -f "$file_backup" ]]; then
    mv "$file_backup" "$CONFIG_HOME/$file_name"
    if ((${#matches} > 1)); then
      rm -f "${matches[@]}"
    fi
    commit_file "$file_name"
  fi
}

backupjson() {
  local file_pattern="${1:-}"
  local file_name="${2:-}"
  local -a matches
  matches=($HOME/Downloads/$~file_pattern(Nom))
  local file_backup="${matches[1]:-}"
  if [[ -n "$file_backup" && -f "$file_backup" ]]; then
    if jq . "$file_backup" >"$CONFIG_HOME/$file_name.tmp" 2>/dev/null; then
      mv "$CONFIG_HOME/$file_name.tmp" "$CONFIG_HOME/$file_name"
    else
      mv "$file_backup" "$CONFIG_HOME/$file_name"
    fi
    rm -f "${matches[@]}"
    commit_file "$file_name"
  fi
}

# 4. Backup extension configurations
backup "my-ublock-backup*.txt" "ubo-config.txt"
backupjson "my-ubol-settings*.json" "ubol-config.json"
backupjson "immersive-translate-config*.json" "immersive-translate-config.json"
backupjson "tampermonkey-backup*.*" "tampermonkey.json"
backupjson "tongwentang*.json" "tongwentang.json"
backupjson "stylus*.json" "stylus.json"

# 5. Push updates to remote if changes were committed
if ((NEED_PUSH)); then
  (
    cd "$CONFIG_HOME"
    git push -q
  )
fi
