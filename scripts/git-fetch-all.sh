#! /bin/bash
printf "\nUpdate all Repositories in ~/GitHub\n"
BASE_DIR="/Users/$(whoami)/GitHub/"
cd "$BASE_DIR"
for f in $(ls $BASE_DIR); do
  cd "$BASE_DIR/$f"
  printf "+ git pull: %s\n" $f
  git pull
done

printf "\nUpdate all Repositories in ~/BOX\n"
BASE_DIR="/Users/$(whoami)/BOX/"
cd "$BASE_DIR"
for f in $(ls $BASE_DIR); do
  if [ "$f" != "_data" ] && [ "$f" != "_data_local" ]; then
    cd "$BASE_DIR/$f"
    printf "+ git pull: %s\n" $f
    git pull
  fi
done
