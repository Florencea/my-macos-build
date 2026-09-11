function fish_prompt
    set_color green
    echo -n (string replace "$HOME" "~" $PWD)
    
    set_color cyan
    fish_git_prompt
    
    set_color normal
    echo -n ' '
end
