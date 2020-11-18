#! /bin/bash
# nano ~/.config/fish/config.fish
# alias ubk="sh ~/GitHub/my-macos-build/scripts/ublock-backup.sh"
FILE_TO_BACKUP=$(find ~/Downloads -maxdepth 1 -name 'my-ublock-backup*.txt' | head -n1)
FILE_NAME=ublock-advanced.txt
PROJECT_DIR=~/GitHub/my-macos-build/configs/
if [ -f "$FILE_TO_BACKUP" ]; then
  mv "$FILE_TO_BACKUP" "$PROJECT_DIR$FILE_NAME"
  cd $PROJECT_DIR || exit
  git add $FILE_NAME
  echo ""
  printf 'File: %s\n' "$FILE_TO_BACKUP"
  printf '     --> ublock-advanced.txt\n\n'
  printf 'Backup to github...'
  git commit -q -m "feat: update ublock-adv rules by ubk"
  git push -q
  echo "done."
  echo ""
else
  echo "Error: No ublock backups in ~/Downloads"
fi
