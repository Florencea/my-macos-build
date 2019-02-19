#! /bin/bash

function print_step(){
  printf "\E[1;36m"
  printf "\n + %s\n\n" "$1"
  printf "\E[0m"
}

# default configuations
default_github_username="Florencea"
default_github_email="bearflorencea@gmail.com"
default_github_editor="nano"
default_shell_greeting="Welcome, Princess Florencea."

# read github config and shell greeting
print_step "read github config and shell greeting"
github_username=$default_github_username
github_email=$default_github_email
github_editor=$default_github_editor
shell_greeting=$default_github_editor
unset user_prompt
while [[ $user_prompt != "y" ]]; do
    printf "\E[1;30m"
    read -rp "Please enter github username(dafault: $default_github_username): " github_username
    read -rp "Please enter github email(dafault: $default_github_email): " github_email
    read -rp "Please enter github editor(dafault: $default_github_editor): " github_editor
    read -erp "Please enter shell greeting(dafault: $default_shell_greeting): " shell_greeting
    printf "\E[0m"
    [ -z "$github_username" ] && github_username=$default_github_username
    [ -z "$github_email" ] && github_email=$default_github_email
    [ -z "$github_editor" ] && github_editor=$default_github_editor
    [ -z "$shell_greeting" ] && shell_greeting=$default_shell_greeting
    printf "\E[0;34m"
    printf "\n"
    printf "github username: %s\n" "$github_username"
    printf "github email: %s\n" "$github_email"
    printf "github editor: %s\n" "$github_editor"
    printf "shell greeting: %s\n" "$shell_greeting"
    printf "\n"
    printf "\E[0m"
    printf "\E[1;31m"
    read -rp "are these correct?(y/n): " user_prompt
    printf "\n"
    printf "\E[0m"
done
# install homebrew
print_step "install homebrew"
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
# brew install fish
print_step "brew install fish"
brew install fish
echo '/usr/local/bin/fish' | sudo tee -a /etc/shells
chsh -s /usr/local/bin/fish
mkdir -p ~/.config/fish
{ printf "set -g -x PATH /usr/local/bin \$PATH\n"; printf "set -g -x fish_greeting %s\n" "$shell_greeting"; } >> ~/.config/fish/config.fish
# brew install commend line tools
print_step "brew install commend line tools"
brew install clang-format
brew install ffmpeg
brew install gcc
brew install git
brew install git-lfs
brew install nano
brew install mkcert
brew install mongodb
brew install node
brew install python
brew install python@2
brew install redis
brew install shellcheck
brew install wget
brew install youtube-dl
# brew install cask apps
print_step "brew install cask apps"
brew tap homebrew/cask-versions
brew cask install atom
brew cask install ezip
brew cask install firefox
brew cask install gpg-suite
brew cask install horndis
brew cask install iina
brew cask install istat-menus
brew cask install kite
brew cask install skype
brew cask install transmission
# brew install cask fonts
print_step "brew install cask fonts"
brew tap homebrew/cask-fonts
brew cask install font-fira-code
brew cask install font-fira-mono
brew cask install font-fira-sans
brew cask install font-noto-sans-cjk
brew cask install font-noto-serif-cjk
# npm install global packages
print_step "npm install global packages"
npm install -g npm
npm install -g http-server
npm install -g eslint
# python3 install global packages
print_step "python3 install global packages"
pip3 install autopep8
pip3 install flake8
pip3 install isort
pip3 install numpy
# mongodb configuations
print_step "mongodb configuations"
(set -x; sudo mkdir -p /data/db)
(set -x; sudo chown "$(whoami)":staff /data/db)
# git configuations
print_step "git configuations"
(set -x; git config --global user.name "$github_username")
(set -x; git config --global user.email "$github_email")
(set -x; git config --global core.editor "$github_editor")
(set -x; git lfs install)
# disable eyecandy
print_step "disable eyecandy"
(set -x; defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO)
# reset launchpad
print_step "reset launchpad"
(set -x; defaults write com.apple.dock ResetLaunchPad -bool true)
(set -x; killall Dock)
# istat-menus licence
print_step "istat-menus licence"
printf "\E[0;31m"
printf "982092332@qq.com\n"
printf "GAWAE-FCWQ3-P8NYB-C7GF7-NEDRT-Q5DTB-MFZG6-6NEQC-CRMUD-8MZ2K-66SRB-SU8EW-EDLZ9-TGH3S-8SGA\n"
printf "\E[0m"
# clear scripts
print_step "clear scripts"
(set -x; rm "$0")
