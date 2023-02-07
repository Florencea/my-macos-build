#! /bin/bash

CONFIG_HOME=$1

# backup $FILE_PATTERN $FILE_NAME
function backup() {
  FILE_PATTERN=$1
  FILE_NAME=$2
  FILE_BACKUP=$(find "$HOME/Downloads" -maxdepth 1 -name "$FILE_PATTERN" | head -n1)
  if [ -f "$FILE_BACKUP" ]; then
    mv "$FILE_BACKUP" "$CONFIG_HOME/$FILE_NAME"
    cd "$CONFIG_HOME" || exit
    git add "$FILE_NAME"
    echo ""
    printf "Find Configuration: %s\n" "$FILE_BACKUP"
    printf "     --> %s\n\n" "$FILE_NAME"
    printf "Backup..."
    git commit -q -m "feat: Update $FILE_NAME by ebk"
    git push -q
    echo "done."
    echo ""
  fi
}

backup "my-ublock-backup*.txt" "ubo-config.txt"
backup "tampermonkey-backup-*.zip" "tampermonkey-backup.zip"
