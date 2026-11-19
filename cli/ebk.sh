#!/usr/bin/env bash
# Backup and sync browser extension configs from ~/Downloads
# Usage: ebk
set -euo pipefail

DOWNLOADS_DIR="$HOME/Downloads"
if [[ ! -d "$DOWNLOADS_DIR" ]]; then
  exit 0
fi

CONFIG_HOME="$(cd "$(dirname "$(realpath "$0")")/../configs" && pwd)"
NEED_PUSH=false

backup_file() {
  local pattern="$1"
  local dest_name="$2"
  local is_json="$3"
  local -a matched=()
  local f newest

  while IFS= read -r -d '' f; do
    matched+=("$f")
  done < <(find "$DOWNLOADS_DIR" -maxdepth 1 -type f -iname "$pattern" -print0)

  if [[ ${#matched[@]} -eq 0 ]]; then
    return 0
  fi

  IFS=$'\t' read -r _ newest < <(stat -f $'%m\t%N' "${matched[@]}" | sort -rn | head -n 1)
  if [[ -z "${newest:-}" || ! -f "$newest" ]]; then
    return 0
  fi

  if [[ "$is_json" == true ]]; then
    jq . "$newest" >"$CONFIG_HOME/$dest_name"
    rm -f "${matched[@]}"
  else
    mv -f "$newest" "$CONFIG_HOME/$dest_name"
    for f in "${matched[@]}"; do
      if [[ "$f" != "$newest" ]]; then
        rm -f "$f"
      fi
    done
  fi

  git -C "$CONFIG_HOME" add -- "$dest_name"
  if [[ -n "$(git -C "$CONFIG_HOME" status --porcelain -- "$dest_name")" ]]; then
    git -C "$CONFIG_HOME" commit -q -m "feat: Update $dest_name by ebk" -- "$dest_name"
    NEED_PUSH=true
    printf "Backup %s ok\n" "$dest_name"
  fi
}

backup_file "my-ublock-backup*.txt" "ubo-config.txt" false
backup_file "my-ubol-settings*.json" "ubol-config.json" true
backup_file "immersive-translate-config*.json" "immersive-translate-config.json" true
backup_file "tampermonkey-backup*.*" "tampermonkey.json" true
backup_file "tongwentang*.json" "tongwentang.json" true
backup_file "stylus*.json" "stylus.json" true

if [[ "$NEED_PUSH" == true ]]; then
  git -C "$CONFIG_HOME" push -q
fi
