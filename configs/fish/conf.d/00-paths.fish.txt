set -gx HOMEBREW_PREFIX "/opt/homebrew"
set -gx HOMEBREW_CELLAR "/opt/homebrew/Cellar"
set -gx HOMEBREW_REPOSITORY "/opt/homebrew"

fish_add_path -g --prepend --move \
    /opt/homebrew/bin \
    /opt/homebrew/sbin \
    /opt/homebrew/opt/bash/bin \
    /opt/homebrew/opt/zsh/bin \
    /opt/homebrew/opt/curl/bin \
    "$HOME/Developer/my-macos-build/cli"