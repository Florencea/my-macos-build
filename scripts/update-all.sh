#! /bin/bash
# nano ~/.config/fish/config.fish
# alias ua="sh ~/Codespaces/my-macos-build/scripts/update-all.sh"

function print_step() {
  printf "\E[1;36m"
  printf "\n+ %s\n\n" "$1"
  printf "\E[0m"
}

print_step "Update command line tools and apps"
cd ~ || exit
(
  set -x
  brew upgrade
  brew cleanup --prune=all
)

WORKSPACE_DIR="/Users/$(whoami)/Codespaces/"
print_step "Update repositories in $WORKSPACE_DIR"
cd "$WORKSPACE_DIR" || exit
for PROJECT in $(ls $WORKSPACE_DIR); do
  cd "$WORKSPACE_DIR/$PROJECT"
  if [ -d .git ]; then
    printf "+ %s\n" $PROJECT
    git pull --all
  fi
done
