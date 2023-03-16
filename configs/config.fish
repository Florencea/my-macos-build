# variables
set BREW_PATH "/opt/homebrew"
set -gx fish_greeting
# path
fish_add_path "$BREW_PATH/bin"
fish_add_path "$BREW_PATH/sbin"
fish_add_path "$BREW_PATH/opt/curl/bin"
fish_add_path "$BREW_PATH/opt/node@18/bin"
# alias
set CODE_SPACE "$HOME/Codespaces"
set CODE_BASE "$CODE_SPACE/my-macos-build"
set SCRIPT_HOME "$CODE_BASE/scripts"
set CONFIG_HOME "$CODE_BASE/configs"
set SCRIPT_PRIVATE_HOME "$HOME/.ssh"
alias mmb="code $CODE_BASE"
alias mkgif="sh $SCRIPT_HOME/mkgif.sh"
alias ebk="sh $SCRIPT_HOME/ebk.sh $CONFIG_HOME"
alias urb="sh $SCRIPT_HOME/urb.sh $SCRIPT_HOME $CONFIG_HOME"
alias ua="sh $SCRIPT_HOME/ua.sh $CODE_SPACE"
alias rec="sh $SCRIPT_HOME/rec.sh"
alias rsl="defaults write com.apple.dock ResetLaunchPad -bool true;killall Dock"
alias boxvpn="sh $SCRIPT_PRIVATE_HOME/boxvpn.sh"
