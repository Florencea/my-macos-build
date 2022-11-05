#! /bin/bash
# nano ~/.config/fish/config.fish
# alias ua="sh ~/Codespaces/my-macos-build/scripts/update-all.sh"

function print_step() {
  printf "\E[1;36m"
  printf "\n + %s\n\n" "$1"
  printf "\E[0m"
}

print_step "Update brew cli and apps"
cd ~ || exit
(
  set -x
  brew upgrade
)

print_step "Update global npm packages"
cd ~ || exit
(
  set -x
  npm update --global
  npm list --global
)

print_step "Update all Repositories in ~/Codespaces"
BASE_DIR="/Users/$(whoami)/Codespaces/"
cd "$BASE_DIR"
for f in $(ls $BASE_DIR); do
  cd "$BASE_DIR/$f"
  if [ -d .git ]; then
    printf "+ git pull --all: %s\n" $f
    git pull --all
  fi
done
