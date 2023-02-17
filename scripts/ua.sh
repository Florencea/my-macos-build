#! /bin/bash

CODE_SPACE=$1

function print_repo() {
  printf "\033[34m"
  printf "==> "
  printf "\033[0m"
  printf "Syncing"
  printf "\033[1m"
  printf " %s" "$1"
  printf "\033[0m"
}

function print_green() {
  printf "\033[32m"
  printf "%s\n" "$1"
  printf "\033[0m"
}

cd "$HOME" || exit
brew upgrade --quiet

cd "$CODE_SPACE" || exit
for PROJECT in $(ls $CODE_SPACE); do
  cd "$CODE_SPACE/$PROJECT"
  if [ -d .git ]; then
    print_repo "$PROJECT"
    git fetch --quiet

    if [ $(git rev-parse HEAD) == $(git rev-parse @{u}) ]; then
      print_green " ✓"
    else
      echo ""
      git pull --all
      echo ""
    fi
  fi
done
