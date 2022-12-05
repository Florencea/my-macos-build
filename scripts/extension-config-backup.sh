#! /bin/bash
# nano ~/.config/fish/config.fish
# alias ebk="sh ~/Codespaces/my-macos-build/scripts/extension-config-backup.sh"
FILE_UBLOCK=$(find ~/Downloads -maxdepth 1 -name 'my-ublock-backup*.txt' | head -n1)
FILE_UBLOCK_NAME=ublock-advanced.txt
FILE_VIOLENTMONKEY=$(find ~/Downloads -maxdepth 1 -name 'violentmonkey_*.zip' | head -n1)
FILE_VIOLENTMONKEY_NAME=violentmonkey-backup.zip

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
# find scripts_*.zip and backup
if [ -f "$FILE_VIOLENTMONKEY" ]; then
  mv "$FILE_VIOLENTMONKEY" "$PROJECT_DIR$FILE_VIOLENTMONKEY_NAME"
  cd $PROJECT_DIR || exit
  git add $FILE_VIOLENTMONKEY_NAME
  echo ""
  printf 'Find VIOLENTMONKEY Configuration: %s\n' "$FILE_VIOLENTMONKEY"
  printf '     --> violentmonkey-backup.zip\n\n'
  printf 'Backup...'
  git commit -q -m "feat: Update violentmonkey Configuration by ebk"
  git push -q
  echo "done."
  echo ""
fi
