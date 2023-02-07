#! /bin/bash

FILE_UBLOCK=$(find ~/Downloads -maxdepth 1 -name 'my-ublock-backup*.txt' | head -n1)
FILE_UBLOCK_NAME=ublock-advanced.txt
FILE_TAMPERMONKEY=$(find ~/Downloads -maxdepth 1 -name 'tampermonkey-backup-*.zip' | head -n1)
FILE_TAMPERMONKEY_NAME=tampermonkey-backup.zip

PROJECT_DIR=~/Codespaces/my-macos-build/configs/

# find my-ublock-backup*.txt and backup
if [ -f "$FILE_UBLOCK" ]; then
  mv "$FILE_UBLOCK" "$PROJECT_DIR$FILE_UBLOCK_NAME"
  cd $PROJECT_DIR || exit
  git add $FILE_UBLOCK_NAME
  echo ""
  printf 'Find uBlock Configuration: %s\n' "$FILE_UBLOCK"
  printf '     --> ublock-advanced.txt\n\n'
  printf 'Backup...'
  git commit -q -m "feat: Update uBlock Configuration by ebk"
  git push -q
  echo "done."
  echo ""
fi
# find tampermonkey-backup-**.zip and backup
if [ -f "$FILE_TAMPERMONKEY" ]; then
  mv "$FILE_TAMPERMONKEY" "$PROJECT_DIR$FILE_TAMPERMONKEY_NAME"
  cd $PROJECT_DIR || exit
  git add $FILE_TAMPERMONKEY_NAME
  echo ""
  printf 'Find TAMPERMONKEY Configuration: %s\n' "$FILE_TAMPERMONKEY"
  printf '     --> tampermonkey-backup.zip\n\n'
  printf 'Backup...'
  git commit -q -m "feat: Update tampermonkey Configuration by ebk"
  git push -q
  echo "done."
  echo ""
fi
