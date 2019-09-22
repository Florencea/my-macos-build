#! /usr/bin/fish
# require fish
# nano ~/.config/fish/config.fish
# alias ubk="fish ~/Documents/workspace_florencea/my-macos-build/ublock-backup.sh"
cd ~/Downloads
set file_to_backup (ls -t | grep my-ublock-backup | head -n1)
if test "$file_to_backup" = ""
  echo "Error: No ublock backups in ~/Downloads"
else
  mv $file_to_backup ~/Documents/workspace_florencea/my-macos-build/ublock-advanced.txt
  cd ~/Documents/workspace_florencea/my-macos-build
  git add ublock-advanced.txt
  git commit -m "feat: update ublock-adv rules by ubk"
  git push
end
