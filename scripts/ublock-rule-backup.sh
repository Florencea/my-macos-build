#! /bin/bash

SCRIPT_HOME=$1
CONFIG_HOME=$2

FILE_LIST="ubo-desktop ubo-mobile ubo-dark"

printf 'Update ec-rules...'

for FILE in ${FILE_LIST}; do
  cd "$HOME"
  python3 "$SCRIPT_HOME/ublock-rule-combiner.py" "$CONFIG_HOME/$FILE.txt"
  cd "$CONFIG_HOME" || exit
  git add "$FILE.txt"
  git add "$FILE.min.txt"
done
git commit -q -m "feat: update ec-rules by urb"
git push -q

echo "done."
