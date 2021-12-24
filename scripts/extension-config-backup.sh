#! /bin/bash
# nano ~/.config/fish/config.fish
# alias ebk="sh ~/GitHub/my-macos-build/scripts/extension-config-backup.sh"
FILE_UBLOCK=$(find ~/Downloads -maxdepth 1 -name 'my-ublock-backup*.txt' | head -n1)
FILE_UBLOCK_NAME=ublock-advanced.txt
FILE_TAMPERMONKEY=$(find ~/Downloads -maxdepth 1 -name 'tampermonkey-backup-*.txt' | head -n1)
FILE_TAMPERMONKEY_NAME=tampermonkey-backup.txt
FILE_TONGWENTANG=$(find ~/Downloads -maxdepth 1 -name 'tongwentang-pref*.json' | head -n1)
FILE_TONGWENTANG_NAME=tongwentang-pref.json
PROJECT_DIR=~/GitHub/my-macos-build/configs/
# find my-ublock-backup*.txt and backup
if [ -f "$FILE_UBLOCK" ]; then
  mv "$FILE_UBLOCK" "$PROJECT_DIR$FILE_UBLOCK_NAME"
  cd $PROJECT_DIR || exit
  git add $FILE_UBLOCK_NAME
  echo ""
  printf 'Find uBlock Configuration: %s\n' "$FILE_UBLOCK"
  printf '     --> ublock-advanced.txt\n\n'
  printf 'Backup to GitHub...'
  git commit -q -m "feat: Update uBlock Configuration by ebk"
  git push -q
  echo "done."
  echo ""
fi
# find tampermonkey-backup-*.txt and backup
if [ -f "$FILE_TAMPERMONKEY" ]; then
  mv "$FILE_TAMPERMONKEY" "$PROJECT_DIR$FILE_TAMPERMONKEY_NAME"
  cd $PROJECT_DIR || exit
  git add $FILE_TAMPERMONKEY_NAME
  echo ""
  printf 'Find Tampermonkey Configuration: %s\n' "$FILE_TAMPERMONKEY"
  printf '     --> tampermonkey-backup.txt\n\n'
  printf 'Backup to GitHub...'
  git commit -q -m "feat: Update Tampermonkey Configuration by ebk"
  git push -q
  echo "done."
  echo ""
fi
# find tongwentang-pref*.json and backup
if [ -f "$FILE_TONGWENTANG" ]; then
  mv "$FILE_TONGWENTANG" "$PROJECT_DIR$FILE_TONGWENTANG_NAME"
  cd $PROJECT_DIR || exit
  git add $FILE_TONGWENTANG_NAME
  echo ""
  printf 'Find NewTongWenTang Configuration: %s\n' "$FILE_TONGWENTANG"
  printf '     --> tongwentang-pref.json\n\n'
  printf 'Backup to GitHub...'
  git commit -q -m "feat: Update NewTongWenTang Configuration by ebk"
  git push -q
  echo "done."
  echo ""
fi
