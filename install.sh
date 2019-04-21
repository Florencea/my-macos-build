#! /bin/bash
github_username="Florencea"
github_email="bearflorencea@gmail.com"
github_editor="nano"
shell_greeting="Welcome, Princess Florencea."
# install homebrew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
# brew install fish
brew install fish
echo '/usr/local/bin/fish' | sudo tee -a /etc/shells
chsh -s /usr/local/bin/fish
mkdir -p ~/.config/fish
{ printf "set -g -x PATH /usr/local/bin \$PATH\n"; printf "set -g -x fish_greeting %s\n" "$shell_greeting"; } >> ~/.config/fish/config.fish
# brew install commend line tools
brew install clang-format
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
# brew install cask apps
brew cask install atom
brew cask install google-chrome
brew cask install gpg-suite
brew cask install iina
brew cask install istat-menus
brew cask install keka
brew cask install kekadefaultapp
# brew install cask fonts
brew tap homebrew/cask-fonts
brew cask install font-fira-code
brew cask install font-fira-mono
# npm install global packages
npm install -g npm
npm install -g http-server
npm install -g eslint
# python3 install global packages
pip3 install autopep8
pip3 install flake8
pip3 install isort
pip3 install numpy
# mongodb configuations
(set -x; sudo mkdir -p /data/db)
(set -x; sudo chown "$(whoami)":staff /data/db)
# git configuations
(set -x; git config --global user.name "$github_username")
(set -x; git config --global user.email "$github_email")
(set -x; git config --global core.editor "$github_editor")
(set -x; git lfs install)
# disable eyecandy
(set -x; defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO)
# reset launchpad
(set -x; defaults write com.apple.dock ResetLaunchPad -bool true)
(set -x; killall Dock)
# istat-menus licence
printf "\E[0;31m"
printf "982092332@qq.com\n"
printf "GAWAE-FCWQ3-P8NYB-C7GF7-NEDRT-Q5DTB-MFZG6-6NEQC-CRMUD-8MZ2K-66SRB-SU8EW-EDLZ9-TGH3S-8SGA\n"
printf "\E[0m"
# clear scripts
(set -x; rm "$0")
