#! /bin/bash
# nano ~/.config/fish/config.fish
# alias ua="sh ~/Codespaces/my-macos-build/scripts/update-all.sh"

function print_step() {
  printf "\033[1m"
  printf "\n%s\n\n" "$1"
  printf "\033[0m"
}

function print_repo() {
  printf "\033[1m"
  printf " - %s\n" "$1"
  printf "\033[0m"
}

cd ~ || exit
brew upgrade

WORKSPACE_DIR="/Users/$(whoami)/Codespaces/"
print_step "Update repositories in $WORKSPACE_DIR"
cd "$WORKSPACE_DIR" || exit
for PROJECT in $(ls $WORKSPACE_DIR); do
  cd "$WORKSPACE_DIR/$PROJECT"
  if [ -d .git ]; then
    print_repo "$PROJECT"
    git pull --all
  fi
done

echo ""
