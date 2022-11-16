#! /bin/bash
# nano ~/.config/fish/config.fish
# alias ua="sh ~/Codespaces/my-macos-build/scripts/update-all.sh"

function print_step() {
  printf "\E[1;36m"
  printf "\n+ %s\n\n" "$1"
  printf "\E[0m"
}

print_step "Update brew cli, apps"
cd ~ || exit
brew upgrade

BASE_DIR="/Users/$(whoami)/Codespaces/"
print_step "Update all Repositories in $BASE_DIR"
cd "$BASE_DIR" || exit
for dir in $(ls $BASE_DIR); do
  cd "$BASE_DIR/$dir"
  if [ -d .git ]; then
    printf "+ %s\n" $dir
    git pull --all
  fi
done
