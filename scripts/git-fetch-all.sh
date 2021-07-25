#! /bin/bash
printf "\nUpdate all Repositories in ~/GitHub\n"
BASE_DIR="/Users/$(whoami)/GitHub/"
cd "$BASE_DIR"
for f in $(ls $BASE_DIR); do
  cd "$BASE_DIR/$f"
  printf "+ git pull: %s\n" $f
  git pull
done
