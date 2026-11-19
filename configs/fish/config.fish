if not status is-interactive
    exit
end

set -g fish_greeting

abbr -a nr 'npm run'
abbr -a la 'ls -lah'
abbr -a ll 'ls -lh'
