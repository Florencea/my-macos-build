#! /bin/bash
# nano ~/.config/fish/config.fish
# alias ua="sh ~/GitHub/my-macos-build/scripts/update-all.sh"
cd ~ || exit
set -x
brew upgrade
