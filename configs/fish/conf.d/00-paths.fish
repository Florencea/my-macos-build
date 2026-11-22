if test -x /opt/homebrew/bin/brew
    /opt/homebrew/bin/brew shellenv fish | source
else if test -x /usr/local/bin/brew
    /opt/homebrew/bin/brew shellenv fish | source
end

fish_add_path -g --prepend --move "$HOME/.local/bin"

if test -d "$HOME/go/bin"
    fish_add_path -g --append "$HOME/go/bin"
end
