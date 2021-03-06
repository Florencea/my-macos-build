#! /bin/bash
# nano ~/.config/fish/config.fish
# alias afx="sh ~/GitHub/my-macos-build/scripts/atom-package-fix.sh"
function print_step() {
  printf "\E[1;36m"
  printf "\n + %s\n\n" "$1"
  printf "\E[0m"
}

print_step "Solving error for Atom package beautysh"
PROJECT_DIR=~/GitHub/my-macos-build/apm-fix/
DISTINATION_DIR=~/.atom/packages/atom-beautify/src/beautifiers/
FILE_NAME=beautysh.coffee
(
  set -x
  cp $PROJECT_DIR$FILE_NAME $DISTINATION_DIR$FILE_NAME
)

print_step "Solving error for Atom package clang-format"
PROJECT_DIR=~/GitHub/my-macos-build/apm-fix/
DISTINATION_DIR=~/.atom/packages/atom-beautify/src/beautifiers/
FILE_NAME=clang-format.coffee
(
  set -x
  cp $PROJECT_DIR$FILE_NAME $DISTINATION_DIR$FILE_NAME
)
