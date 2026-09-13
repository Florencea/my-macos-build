if test -x /opt/homebrew/bin/brew
    /opt/homebrew/bin/brew shellenv fish | source
end

fish_add_path -g --prepend --move \
    /opt/homebrew/opt/bash/bin \
    /opt/homebrew/opt/zsh/bin \
    /opt/homebrew/opt/curl/bin \
    "$HOME/.local/bin"
