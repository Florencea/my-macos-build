#! /bin/bash

SCRIPT_HOME=$1
CONFIG_HOME=$2

FILE_LIST="ubo-desktop ubo-mobile ubo-font"

printf 'Update ubo-rules...'

for FILE in ${FILE_LIST}; do
  cd "$HOME"
  python3 "$SCRIPT_HOME/urb.py" "$CONFIG_HOME/$FILE.txt"
  cd "$CONFIG_HOME" || exit
  git add "$FILE.txt"
  git add "$FILE.min.txt"
done
git commit -q -m "feat: update ubo-rules by urb"
git push -q

echo "done."
