#!/usr/bin/env zsh
# nano ~/.config/fish/config.fish
# alias ua="sh ~/GitHub/my-macos-build/scripts/update-all.sh"
cd ~
set -x
brew upgrade
apm update
npm update -g
