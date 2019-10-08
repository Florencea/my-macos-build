#! /bin/bash
function print_step(){
  printf "\E[1;36m"
  printf "\n + %s\n\n" "$1"
  printf "\E[0m"
}

github_username="Florencea"
github_email="bearflorencea@gmail.com"
github_editor="nano"
shell_greeting="Welcome, Princess Florencea."

print_step "install homebrew"
# /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)"

print_step "brew install fish"
brew install fish
echo '/usr/local/bin/fish' | sudo tee -a /etc/shells
chsh -s /usr/local/bin/fish
mkdir -p ~/.config/fish
printf "set -g -x PATH /usr/local/bin \$PATH\n" >> ~/.config/fish/config.fish
printf "set -g -x fish_greeting %s\n" "$shell_greeting" >> ~/.config/fish/config.fish
printf "alias mmb=\"atom ~/GitHub/my-macos-build\"\n" >> ~/.config/fish/config.fish
printf "alias mkgif=\"fish ~/GitHub/my-macos-build/make-gif.sh\"\n" >> ~/.config/fish/config.fish
printf "alias ubk=\"fish ~/GitHub/my-macos-build/ublock-backup.sh\"\n" >> ~/.config/fish/config.fish
printf "alias al=\"fish ~/GitHub/ledger/al/al.fish\"\n" >> ~/.config/fish/config.fish

print_step "brew install commend line tools"
brew install clang-format
brew install ccls
brew install ffmpeg
brew install gcc
brew install gdrive
brew install git
brew install git-lfs
brew install id3v2
brew install jq
brew install nano
brew install megatools
brew install mkcert
brew install node
brew install nss
brew install python
brew install python@2
brew install redis
brew install wget
brew install youtube-dl

print_step "brew install cask apps"
brew cask install atom
brew cask install google-chrome
brew cask install gpg-suite
brew cask install iina
brew cask install keka
brew cask install kekadefaultapp

print_step "brew install cask fonts"
brew tap homebrew/cask-fonts
brew cask install font-fira-code

print_step "npm install global packages"
npm install -g npm
npm install -g http-server
npm install -g eslint

print_step "python3 install global packages"
pip3 install autopep8
pip3 install flake8
pip3 install isort
pip3 install numpy
pip3 install 'python-language-server[all]'

print_step "mongodb install and configuations"
brew tap mongodb/brew
brew install mongodb-community

print_step "git configuations"
(set -x; git config --global user.name "$github_username")
(set -x; git config --global user.email "$github_email")
(set -x; git config --global core.editor "$github_editor")
(set -x; git lfs install)

print_step "reset launchpad"
(set -x; defaults write com.apple.dock ResetLaunchPad -bool true)
(set -x; killall Dock)

print_step "clear scripts"
(set -x; rm "$0")
