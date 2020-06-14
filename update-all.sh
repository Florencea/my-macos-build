#!/usr/bin/env zsh
# nano ~/.config/fish/config.fish
# alias ua="sh ~/GitHub/my-macos-build/update-all.sh"
cd ~
set -x
brew update
brew upgrade
apm-nightly update
npm update -g
