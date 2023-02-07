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

function print_red() {
  printf "\033[31m"
  printf "%s\n" "$1"
  printf "\033[0m"
}

cd "$HOME" || exit
brew upgrade

cd "$CODE_SPACE" || exit
for PROJECT in $(ls $CODE_SPACE); do
  cd "$CODE_SPACE/$PROJECT"
  if [ -d .git ]; then
    print_repo "$PROJECT"
    git fetch --quiet

    UPSTREAM=${1:-'@{u}'}
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse "$UPSTREAM")
    BASE=$(git merge-base @ "$UPSTREAM")

    if [ $LOCAL = $REMOTE ]; then
      print_green " ✓"
    elif [ $LOCAL = $BASE ]; then
      echo ""
      git pull --all
      echo ""
    elif [ $REMOTE = $BASE ]; then
      print_red " ↑"
      echo ""
      git status
      echo ""
    else
      print_red " ✕"
      echo ""
      git status
    fi
  fi
done
