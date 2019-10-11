#!/usr/bin/env zsh
# nano ~/.config/fish/config.fish
# alias ubk="sh ~/GitHub/my-macos-build/ublock-backup.sh"
cd ~/Downloads
FILE_TO_BACKUP=$(ls -t | grep my-ublock-backup | head -n1)
FILE_NAME=ublock-advanced.txt
PROJECT_DIR=~/GitHub/my-macos-build/
if [ -f "$FILE_TO_BACKUP" ]; then
  mv $FILE_TO_BACKUP $PROJECT_DIR$FILE_NAME
  cd $PROJECT_DIR
  git add $FILE_NAME
  echo ""
  printf 'Backup to github...'
  git commit -q -m "feat: update ublock-adv rules by ubk"
  git push -q
  echo "done."
  echo ""
else
  echo "Error: No ublock backups in ~/Downloads"
fi
